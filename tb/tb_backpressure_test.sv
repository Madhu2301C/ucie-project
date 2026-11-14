`timescale 1ns/1ps
module tb_backpressure_test;
    logic clk = 0, rst_n, send_req, inject_error, tx_ready;
    logic [511:0] payload;
    logic [7:0] sequence_num;
    logic tx_valid, busy, done, crc_error_seen, retransmit;
    logic [31:0] retransmission_count;
    logic [511:0] received_payload;
    logic [543:0] held_flit, held_link_flit, held_retry_buffer;
    bit stall_active = 0;
    integer stalled_checks = 0;
    integer deliveries = 0, accepts = 0;
    ucie_link_top dut (.*);
    always #5 clk = ~clk;
    always @(posedge clk) begin
        if (!rst_n) begin deliveries = 0; accepts = 0; stalled_checks = 0; end
        else begin
            // Check every rising edge from capture through acceptance.
            // A dropped valid cannot disable this check.
            if (stall_active) begin
                if (tx_valid !== 1'b1 || dut.link_flit !== held_link_flit ||
                    dut.retry_flit !== held_flit || dut.u_retry.retry_buffer !== held_retry_buffer)
                    $fatal(1, "FAIL: stalled valid/flit/retry buffer stability");
                if (tx_ready === 1'b0) stalled_checks = stalled_checks + 1;
                else if (tx_ready === 1'b1) stall_active = 0;
                else $fatal(1, "FAIL: unknown ready during stall");
            end
            if (tx_valid && tx_ready) begin
            accepts = accepts + 1;
            if (dut.rx_crc_error !== 1'b0 || dut.rx_flit_valid !== 1'b1)
                $fatal(1, "FAIL: accepted invalid flit");
            deliveries = deliveries + 1;
            end
        end
    end
    initial begin
        rst_n = 0; send_req = 0; payload = '0; sequence_num = 8'h12;
        inject_error = 0; tx_ready = 0;
        repeat (3) @(negedge clk); rst_n = 1;
        @(negedge clk); payload = {16{32'habcd1234}}; send_req = 1;
        @(negedge clk); send_req = 0;
        if (tx_valid !== 1'b1 || tx_ready !== 1'b0)
            $fatal(1, "FAIL: expected valid stalled transaction at capture");
        held_flit = dut.retry_flit;
        held_link_flit = dut.link_flit;
        held_retry_buffer = dut.u_retry.retry_buffer;
        stall_active = 1;
        repeat (5) begin
            @(negedge clk);
            if (tx_valid !== 1'b1 || busy !== 1'b1 || done !== 1'b0 ||
                dut.retry_flit !== held_flit || dut.link_flit !== held_link_flit ||
                dut.u_retry.retry_buffer !== held_retry_buffer || accepts != 0 || deliveries != 0 ||
                retransmission_count !== 32'd0)
                $fatal(1, "FAIL: stalled transaction changed or delivered");
        end
        tx_ready = 1;
        wait (deliveries == 1); wait (busy === 1'b0);
        repeat (3) @(negedge clk);
        if (done !== 1'b1 || received_payload !== payload || deliveries != 1 ||
            accepts != 1 || stalled_checks != 5 || stall_active || retransmission_count !== 32'd0 || crc_error_seen !== 1'b0)
            $fatal(1, "FAIL: completion after backpressure");
        $display("ALL BACKPRESSURE TESTS PASSED: accepts=%0d deliveries=%0d stalled_checks=%0d", accepts, deliveries, stalled_checks);
        $display("REGRESSION_PASS: tb_backpressure_test");
        $finish;
    end
    initial begin #1000; $fatal(1, "FAIL: backpressure timeout"); end
endmodule
