
module tb_ucie_link_top;

    logic clk, rst_n;
    logic send_req, inject_error, tx_ready;
    logic [511:0] payload;
    logic [7:0] sequence_num;

    logic tx_valid, busy, done;
    logic crc_error_seen, retransmit;
    logic [31:0] retransmission_count;
    logic [511:0] received_payload;

    ucie_link_top dut (
        .clk                  (clk),
        .rst_n                (rst_n),
        .send_req             (send_req),
        .payload              (payload),
        .sequence_num         (sequence_num),
        .inject_error         (inject_error),
        .tx_ready             (tx_ready),
        .tx_valid             (tx_valid),
        .busy                 (busy),
        .done                 (done),
        .crc_error_seen       (crc_error_seen),
        .retransmit            (retransmit),
        .retransmission_count (retransmission_count),
        .received_payload     (received_payload)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    initial begin
        rst_n       = 1'b0;
        send_req    = 1'b0;
        inject_error = 1'b0;
        tx_ready    = 1'b1;
        payload     = '0;
        sequence_num = 8'h12;

        repeat (3) @(negedge clk);
        rst_n = 1'b1;

        // Use a nonzero, reproducible payload.
        payload = 512'h123456789ABCDEF001122334455667788;
        inject_error = 1'b1;

        @(negedge clk);
        send_req = 1'b1;

        @(negedge clk);
        send_req = 1'b0;

        // Wait for successful reception after retry.
        fork
            begin
                wait (done == 1'b1);
            end
            begin
                repeat (100) @(posedge clk);
                $fatal(1, "FAIL: end-to-end timeout");
            end
        join_any
        disable fork;

        // Allow registered ACK to clear the pending transaction.
        repeat (2) @(negedge clk);
        #1;

        if (!crc_error_seen)
            $fatal(1, "FAIL: corrupted flit was not detected");

        $display("PASS: injected error detected");

        if (retransmission_count != 1)
            $fatal(1, "FAIL: expected one retransmission, got %0d",
                   retransmission_count);

        $display("PASS: exactly one retransmission");

        if (received_payload !== payload)
            $fatal(1, "FAIL: received payload mismatch");

        $display("PASS: payload recovered correctly");

        if (busy)
            $fatal(1, "FAIL: controller still busy after ACK");

        $display("PASS: ACK completed the transaction");
        $display("ALL END-TO-END TESTS PASSED");

        $finish;
    end

endmodule
