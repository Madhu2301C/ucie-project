`timescale 1ns/1ps
module tb_ucie_link_top;
    logic clk = 0, rst_n;
    logic send_req, inject_error, tx_ready;
    logic [511:0] payload;
    logic [7:0] sequence_num;
    logic tx_valid, busy, done, crc_error_seen, retransmit;
    logic [31:0] retransmission_count;
    logic [511:0] received_payload;
    integer deliveries = 0, errors = 0, accepts = 0;
    bit done_seen = 0;
    logic [511:0] payload_before_corruption;
    logic [543:0] original_flit;
    integer failed_checks = 0, replay_checks = 0;
    ucie_link_top dut (.*);
    always #5 clk = ~clk;
    // Sample the same pre-NBA handshake as the receiver. done is sticky.
    always @(posedge clk) begin
        if (!rst_n) begin
            deliveries = 0; errors = 0; accepts = 0; done_seen = 0;
            failed_checks = 0; replay_checks = 0;
        end else begin
            if (done_seen && done !== 1'b1) $fatal(1, "FAIL: done lost sticky state");
            if (done === 1'b1) done_seen = 1;
            if (tx_valid && tx_ready) begin
                accepts = accepts + 1;
                // Identify intended corruption independently of the RX verdict.
                if (inject_error && !dut.injected_once) begin
                    original_flit = dut.retry_flit;
                    if (dut.rx_crc_error !== 1'b1 || dut.rx_flit_valid !== 1'b0 ||
                        received_payload !== payload_before_corruption || retransmit !== 1'b0)
                        $fatal(1, "FAIL: corrupted handshake CRC/status/payload");
                    errors = errors + 1;
                    // Feedback and payload registers update in this edge's NBA region.
                    #1;
                    if (dut.nak_reg !== 1'b1 || dut.ack_reg !== 1'b0 ||
                        crc_error_seen !== 1'b1 || received_payload !== payload_before_corruption ||
                        deliveries != 0 || done !== 1'b0)
                        $fatal(1, "FAIL: failed flit feedback or payload preservation");
                    failed_checks = failed_checks + 1;
                    $display("PASS: failed handshake CRC error; NAK=1 ACK=0; payload unchanged");
                end else if (dut.rx_crc_error === 1'b0 && dut.rx_flit_valid === 1'b1) begin
                    if (deliveries == 0) begin
                        if (failed_checks != 1 || retransmit !== 1'b1 ||
                            dut.link_flit !== original_flit)
                            $fatal(1, "FAIL: expected intact replay after rejected flit");
                        replay_checks = replay_checks + 1;
                    end else if (retransmit !== 1'b0)
                        $fatal(1, "FAIL: unexpected second transaction replay");
                    deliveries = deliveries + 1;
                    if (dut.rx_payload !== payload) $fatal(1, "FAIL: accepted payload");
                    #1;
                    if (dut.ack_reg !== 1'b1 || dut.nak_reg !== 1'b0 ||
                        received_payload !== payload || done !== 1'b1)
                        $fatal(1, "FAIL: successful delivery feedback/payload");
                end else $fatal(1, "FAIL: unknown receive status");
            end
        end
    end
    task automatic send_one(input integer target);
        @(negedge clk); send_req = 1;
        @(negedge clk); send_req = 0;
        // A previous transaction may already have set done.
        wait (deliveries == target);
        wait (busy === 1'b0);
        @(negedge clk);
        if (done !== 1'b1 || received_payload !== payload)
            $fatal(1, "FAIL: completion/payload transaction %0d", target);
    endtask
    initial begin
        rst_n = 0; send_req = 0; inject_error = 1; tx_ready = 1;
        payload = '0; sequence_num = 8'h12;
        repeat (3) @(negedge clk); rst_n = 1;
        payload = {16{32'h12345678}};
        payload_before_corruption = received_payload;
        send_one(1);
        if (deliveries != 1 || failed_checks != 1 || replay_checks != 1)
            $fatal(1, "FAIL: first transaction must deliver exactly once after replay");
        if (errors != 1 || accepts != 2 || retransmission_count !== 32'd1 ||
            crc_error_seen !== 1'b1) $fatal(1, "FAIL: first transaction retry counts");
        payload = {16{32'h89abcdef}}; sequence_num = 8'h34;
        // Injection remains enabled, but the existing injector fires once per reset.
        send_one(2);
        repeat (3) @(negedge clk);
        if (deliveries != 2 || errors != 1 || accepts != 3 ||
            failed_checks != 1 || replay_checks != 1 ||
            retransmission_count !== 32'd1 || busy !== 1'b0 || done !== 1'b1)
            $fatal(1, "FAIL: second transaction/sticky completion counts");
        $display("ALL END-TO-END TESTS PASSED: deliveries=%0d errors=%0d accepts=%0d retries=%0d", deliveries, errors, accepts, retransmission_count);
        $display("REGRESSION_PASS: tb_ucie_link_top");
        $finish;
    end
    initial begin #2000; $fatal(1, "FAIL: link timeout"); end
endmodule
