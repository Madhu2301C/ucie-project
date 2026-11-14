`timescale 1ns/1ps

module tb_ucie_retry_controller;

    parameter FLIT_WIDTH = 544;
    parameter TIMEOUT_CYCLES = 5;

    logic clk;
    logic rst_n;

    logic send_req;
    logic [FLIT_WIDTH-1:0] tx_flit;

    logic tx_ready;
    logic ack;
    logic nak;

    logic tx_valid;
    logic [FLIT_WIDTH-1:0] tx_flit_out;
    logic busy;
    logic retransmit;
    logic timeout_pulse;

    integer test_count;

    // ------------------------------------------------
    // DUT
    // ------------------------------------------------

    ucie_retry_controller #(
        .FLIT_WIDTH(FLIT_WIDTH),
        .TIMEOUT_CYCLES(TIMEOUT_CYCLES)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),

        .send_req(send_req),
        .tx_flit(tx_flit),

        .tx_ready(tx_ready),
        .ack(ack),
        .nak(nak),

        .tx_valid(tx_valid),
        .tx_flit_out(tx_flit_out),
        .busy(busy),
        .retransmit(retransmit),
        .timeout_pulse(timeout_pulse)
    );

    // ------------------------------------------------
    // Clock generation
    // ------------------------------------------------

    initial clk = 1'b0;

    always #5 clk = ~clk;

    // ------------------------------------------------
    // Common transaction tasks
    // ------------------------------------------------

    task automatic reset_dut;
        begin
            @(negedge clk);
            rst_n    = 1'b0;
            send_req = 1'b0;
            tx_ready = 1'b0;
            ack      = 1'b0;
            nak      = 1'b0;
            tx_flit  = '0;

            repeat (3) @(negedge clk);

            rst_n = 1'b1;

            @(negedge clk);

            if (busy !== 1'b0)
                $fatal(1, "RESET FAIL: busy is not zero");

            if (tx_valid !== 1'b0)
                $fatal(1, "RESET FAIL: tx_valid is not zero");
        end
    endtask

    task automatic start_transaction(
        input logic [FLIT_WIDTH-1:0] data
    );
        integer guard;
        begin
            @(negedge clk);

            tx_flit  = data;
            send_req = 1'b1;

            @(negedge clk);
            send_req = 1'b0;

            guard = 0;

            while (tx_valid !== 1'b1 && guard < 10) begin
                @(negedge clk);
                guard = guard + 1;
            end

            if (tx_valid !== 1'b1)
                $fatal(1, "FAIL: Original transmission did not start");

            if (tx_flit_out !== data)
                $fatal(1, "FAIL: Original flit mismatch");

            if (busy !== 1'b1)
                $fatal(1, "FAIL: busy not asserted");

            // Accept original transmission
            tx_ready = 1'b1;

            @(negedge clk);
            tx_ready = 1'b0;
        end
    endtask

    task automatic accept_replay(
        input logic [FLIT_WIDTH-1:0] expected_data,
        input integer stall_cycles
    );
        integer guard;
        integer k;
        begin
            guard = 0;

            while (tx_valid !== 1'b1 && guard < 10) begin
                @(negedge clk);
                guard = guard + 1;
            end

            if (tx_valid !== 1'b1)
                $fatal(1, "FAIL: Replay transmission did not start");

            if (tx_flit_out !== expected_data)
                $fatal(1, "FAIL: Replayed flit does not match original");

            if (retransmit !== 1'b0)
                $fatal(1, "FAIL: retransmit should be low before acceptance");

            // Hold replay under backpressure
            for (k = 0; k < stall_cycles; k = k + 1) begin
                if (tx_valid !== 1'b1)
                    $fatal(1, "FAIL: tx_valid dropped during replay stall");

                if (tx_flit_out !== expected_data)
                    $fatal(1, "FAIL: Replay data changed during stall");

                @(negedge clk);
            end

            // Accept replay
            tx_ready = 1'b1;

            #1;

            if (retransmit !== 1'b1)
                $fatal(1, "FAIL: retransmit not asserted on replay acceptance");

            @(negedge clk);
            tx_ready = 1'b0;
        end
    endtask

    task automatic send_nak;
        begin
            @(negedge clk);
            nak = 1'b1;

            @(negedge clk);
            nak = 1'b0;
        end
    endtask

    task automatic send_ack;
        begin
            @(negedge clk);
            ack = 1'b1;

            @(negedge clk);
            ack = 1'b0;

            if (busy !== 1'b0)
                $fatal(1, "FAIL: Controller did not return to IDLE after ACK");
        end
    endtask

    // ------------------------------------------------
    // Test sequence
    // ------------------------------------------------

    initial begin

        test_count = 0;

        rst_n    = 1'b0;
        send_req = 1'b0;
        tx_flit  = '0;
        tx_ready = 1'b0;
        ack      = 1'b0;
        nak      = 1'b0;

        // ============================================
        // TC01: Normal ACK completion
        // ============================================

        reset_dut();

        test_count = test_count + 1;

        start_transaction(544'h123456789ABCDEF);

        send_ack();

        if (busy !== 1'b0)
            $fatal(1, "TC01 FAIL: Controller still busy");

        $display("TC01 PASS: Normal ACK completion");

        // ============================================
        // TC02: NAK-triggered replay
        // ============================================

        reset_dut();

        test_count = test_count + 1;

        start_transaction(544'hA123456789ABCDEF);

        send_nak();

        accept_replay(544'hA123456789ABCDEF, 0);

        send_ack();

        $display("TC02 PASS: NAK-triggered replay");

        // ============================================
        // TC03: Timeout-triggered replay
        // ============================================

        reset_dut();

        test_count = test_count + 1;

        start_transaction(544'hB123456789ABCDEF);

        begin : timeout_test
            integer guard;

            guard = 0;

            while (timeout_pulse !== 1'b1 && guard < 20) begin
                @(negedge clk);
                guard = guard + 1;
            end

            if (timeout_pulse !== 1'b1)
                $fatal(1, "TC03 FAIL: Timeout not generated");
        end

        accept_replay(544'hB123456789ABCDEF, 0);

        send_ack();

        $display("TC03 PASS: Timeout-triggered replay");

        // ============================================
        // TC04: Simultaneous ACK and NAK
        // ACK has priority in the RTL
        // ============================================

        reset_dut();

        test_count = test_count + 1;

        start_transaction(544'hC123456789ABCDEF);

        @(negedge clk);

        ack = 1'b1;
        nak = 1'b1;

        @(negedge clk);

        ack = 1'b0;
        nak = 1'b0;

        if (busy !== 1'b0)
            $fatal(1, "TC04 FAIL: ACK priority not respected");

        if (tx_valid !== 1'b0)
            $fatal(1, "TC04 FAIL: Unexpected replay after ACK");

        $display("TC04 PASS: Simultaneous ACK and NAK");

        // ============================================
        // TC05: Multiple consecutive NAKs
        // ============================================

        reset_dut();

        test_count = test_count + 1;

        start_transaction(544'hD123456789ABCDEF);

        send_nak();
        accept_replay(544'hD123456789ABCDEF, 0);

        send_nak();
        accept_replay(544'hD123456789ABCDEF, 0);

        send_nak();
        accept_replay(544'hD123456789ABCDEF, 0);

        send_ack();

        $display("TC05 PASS: Multiple consecutive NAKs");

        // ============================================
        // TC06: Backpressure during replay
        // ============================================

        reset_dut();

        test_count = test_count + 1;

        start_transaction(544'hE123456789ABCDEF);

        send_nak();

        accept_replay(544'hE123456789ABCDEF, 3);

        send_ack();

        $display("TC06 PASS: Backpressure during replay");

        // ============================================
        // TC07: Asynchronous reset during SEND_NEW
        // ============================================

        reset_dut();
        test_count = test_count + 1;

        @(negedge clk);
        tx_flit  = 544'hF123456789ABCDEF;
        send_req = 1'b1;
        @(negedge clk);
        send_req = 1'b0;

        if (tx_valid !== 1'b1 || busy !== 1'b1)
            $fatal(1, "TC07 FAIL: Controller did not enter SEND_NEW");

        rst_n = 1'b0;
        #1;
        if (busy !== 1'b0 || tx_valid !== 1'b0 || retransmit !== 1'b0 ||
            timeout_pulse !== 1'b0 || tx_flit_out !== '0)
            $fatal(1, "TC07 FAIL: Reset did not clear SEND_NEW outputs");

        repeat (2) @(negedge clk);
        rst_n = 1'b1;
        @(negedge clk);
        $display("TC07 PASS: Reset during SEND_NEW");

        // ============================================
        // TC08: Asynchronous reset during WAIT_ACK
        // ============================================

        reset_dut();
        test_count = test_count + 1;
        start_transaction(544'hF223456789ABCDEF);

        rst_n = 1'b0;
        #1;
        if (busy !== 1'b0 || tx_valid !== 1'b0 || timeout_pulse !== 1'b0)
            $fatal(1, "TC08 FAIL: Reset did not clear WAIT_ACK");

        repeat (2) @(negedge clk);
        rst_n = 1'b1;
        @(negedge clk);
        $display("TC08 PASS: Reset during WAIT_ACK");

        // ============================================
        // TC09: Asynchronous reset during SEND_REPLAY
        // ============================================

        reset_dut();
        test_count = test_count + 1;
        start_transaction(544'hF323456789ABCDEF);
        send_nak();

        if (tx_valid !== 1'b1 || tx_flit_out !== 544'hF323456789ABCDEF)
            $fatal(1, "TC09 FAIL: Controller did not enter SEND_REPLAY");

        rst_n = 1'b0;
        #1;
        if (busy !== 1'b0 || tx_valid !== 1'b0 || retransmit !== 1'b0 ||
            timeout_pulse !== 1'b0 || tx_flit_out !== '0)
            $fatal(1, "TC09 FAIL: Reset did not clear SEND_REPLAY outputs");

        repeat (2) @(negedge clk);
        rst_n = 1'b1;
        @(negedge clk);
        $display("TC09 PASS: Reset during SEND_REPLAY");

        // ============================================
        // TC10: Exact timeout boundary
        // TIMEOUT_CYCLES complete WAIT_ACK clocks must elapse before
        // timeout_pulse is asserted.
        // ============================================

        reset_dut();
        test_count = test_count + 1;
        start_transaction(544'hF423456789ABCDEF);

        begin : timeout_boundary_test
            integer cycle;

            for (cycle = 1; cycle < TIMEOUT_CYCLES; cycle = cycle + 1) begin
                @(posedge clk);
                #1;
                if (timeout_pulse !== 1'b0)
                    $fatal(1,
                           "TC10 FAIL: Early timeout at WAIT_ACK cycle %0d",
                           cycle);
            end

            @(posedge clk);
            #1;
            if (timeout_pulse !== 1'b1)
                $fatal(1,
                       "TC10 FAIL: Timeout missing after %0d WAIT_ACK cycles",
                       TIMEOUT_CYCLES);
        end

        accept_replay(544'hF423456789ABCDEF, 0);
        send_ack();
        $display("TC10 PASS: Exact timeout boundary");

        // ============================================
        // Final result
        // ============================================

        $display("----------------------------------------");
        $display("RETRY CONTROLLER TESTS COMPLETED");
        $display("TOTAL TESTS: %0d", test_count);
        $display("ALL RETRY CONTROLLER TESTS PASSED");
        $display("REGRESSION_PASS: tb_ucie_retry_controller");
        $display("----------------------------------------");

        $finish;

    end

    // ------------------------------------------------
    // Simulation timeout
    // ------------------------------------------------

    initial begin
        #100000;
        $fatal(1, "GLOBAL TIMEOUT: Retry controller testbench");
    end

endmodule
