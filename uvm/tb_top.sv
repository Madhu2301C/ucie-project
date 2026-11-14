// ============================================================================
// UCIe UVM Top-Level Testbench
// ============================================================================
// Connects the retry controller DUT to the UVM environment via virtual interface.
// Generates reset, clocks, and configures the virtual interface for UVM agents.
// ============================================================================

module tb_top;

    import uvm_pkg::*;
    import ucie_pkg::*;

    // Clock generation
    bit clk = 0;
    always #5 clk = ~clk;

    // Retry interface
    ucie_retry_if retry_vif(clk);

    // Link interface
    ucie_link_if link_vif(clk);

    // Retry controller DUT
    ucie_retry_controller #(
        .FLIT_WIDTH(544),
        .TIMEOUT_CYCLES(10)
    ) dut (
        .clk           (retry_vif.clk),
        .rst_n         (retry_vif.rst_n),

        .send_req      (retry_vif.send_req),
        .tx_flit       (retry_vif.tx_flit),
        .tx_ready      (retry_vif.tx_ready),
        .ack           (retry_vif.ack),
        .nak           (retry_vif.nak),

        .tx_valid      (retry_vif.tx_valid),
        .tx_flit_out   (retry_vif.tx_flit_out),
        .busy          (retry_vif.busy),
        .retransmit    (retry_vif.retransmit),
        .timeout_pulse (retry_vif.timeout_pulse)
    );

    // Integrated link DUT
    ucie_link_top link_dut (
        .clk                  (link_vif.clk),
        .rst_n                (link_vif.rst_n),
        .send_req             (link_vif.send_req),
        .payload              (link_vif.payload),
        .sequence_num         (link_vif.sequence_num),
        .inject_error         (link_vif.inject_error),
        .tx_ready             (link_vif.tx_ready),
        .tx_valid             (link_vif.tx_valid),
        .busy                 (link_vif.busy),
        .done                 (link_vif.done),
        .crc_error_seen       (link_vif.crc_error_seen),
        .retransmit           (link_vif.retransmit),
        .retransmission_count (link_vif.retransmission_count),
        .received_payload     (link_vif.received_payload)
    );

    // Reset generation
    initial begin

        retry_vif.rst_n = 1'b0;
        retry_vif.send_req = 1'b0;
        retry_vif.tx_flit = '0;
        retry_vif.tx_ready = 1'b0;
        retry_vif.ack = 1'b0;
        retry_vif.nak = 1'b0;

        link_vif.rst_n = 1'b0;
        link_vif.send_req = 1'b0;
        link_vif.payload = '0;
        link_vif.sequence_num = '0;
        link_vif.inject_error = 1'b0;
        link_vif.tx_ready = 1'b0;

        repeat (5) @(posedge clk);
        retry_vif.rst_n = 1'b1;
        link_vif.rst_n = 1'b1;

    end

    // UVM must start at time zero. Test selection is supplied with
    // +UVM_TESTNAME; the default remains ucie_base_test.
    initial begin

        uvm_config_db#(virtual ucie_retry_if)::set(
            null,
            "uvm_test_top.env.retry_agent*",
            "vif",
            retry_vif
        );

        uvm_config_db#(virtual ucie_link_if)::set(
            null,
            "uvm_test_top.env.link_agent*",
            "vif",
            link_vif
        );

        $display("------------------------------------");
        $display(" UCIe UVM Verification Environment ");
        $display("------------------------------------");

        if (!$test$plusargs("UVM_TESTNAME"))
            run_test("ucie_base_test");
        else
            run_test();

    end

endmodule
