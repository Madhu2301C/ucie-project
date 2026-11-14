`ifndef UCIE_LINK_DRIVER_SV
`define UCIE_LINK_DRIVER_SV

class ucie_link_driver extends uvm_driver #(ucie_transaction_item);

    `uvm_component_utils(ucie_link_driver)

    virtual ucie_link_if vif;

    localparam int MAX_WAIT_CYCLES = 200;

    function new(string name = "ucie_link_driver",
                 uvm_component parent = null);
        super.new(name, parent);
    endfunction


    // Get virtual interface
    function void build_phase(uvm_phase phase);

        super.build_phase(phase);

        if (!uvm_config_db #(virtual ucie_link_if)::get(
                this, "", "vif", vif)) begin

            `uvm_fatal("LINK_DRIVER",
                       "ucie_link_if virtual interface not received")
        end

    endfunction


    // Initialize driver inputs
    task drive_idle();

        @(negedge vif.clk);

        vif.send_req     = 1'b0;
        vif.payload      = '0;
        vif.sequence_num = '0;
        vif.inject_error = 1'b0;
        vif.tx_ready     = 1'b0;

    endtask


    // Wait for reset release
    task wait_for_reset();

        wait (vif.rst_n === 1'b1);
        @(negedge vif.clk);

    endtask


    // Drive one link transaction
    task drive_transaction(ucie_transaction_item req);

        int wait_cycles;
        bit busy_seen;

        // Drive transaction inputs
        @(negedge vif.clk);

        vif.payload      = req.payload;
        vif.sequence_num = req.sequence_num;
        vif.inject_error = req.inject_error;
        vif.tx_ready     = 1'b1;

        `uvm_info("LINK_DRIVER",
                  $sformatf(
                      "Driving transaction: sequence=%0d inject_error=%0b",
                      req.sequence_num, req.inject_error),
                  UVM_MEDIUM)

        // Assert send request
        vif.send_req = 1'b1;

        @(negedge vif.clk);
        vif.send_req = 1'b0;

        // Wait for DUT busy
        busy_seen = 0;

        for (wait_cycles = 0;
             wait_cycles < MAX_WAIT_CYCLES;
             wait_cycles++) begin

            @(posedge vif.clk);

            if (vif.busy === 1'b1) begin
                busy_seen = 1;
                break;
            end

        end

        if (!busy_seen) begin
            `uvm_fatal("LINK_DRIVER",
                       "Timeout: DUT did not enter busy state")
        end

        `uvm_info("LINK_DRIVER",
                  "DUT entered BUSY state",
                  UVM_MEDIUM)

        // Wait for transaction completion
        wait_cycles = 0;

        while (vif.done !== 1'b1 &&
               wait_cycles < MAX_WAIT_CYCLES) begin

            @(posedge vif.clk);
            wait_cycles++;

        end

        if (vif.done !== 1'b1) begin
            `uvm_fatal("LINK_DRIVER",
                       "Timeout: DUT did not complete transaction")
        end

        // Wait for retry controller to return to IDLE
        wait_cycles = 0;

        while (vif.busy !== 1'b0 &&
               wait_cycles < MAX_WAIT_CYCLES) begin

            @(posedge vif.clk);
            wait_cycles++;

        end

        if (vif.busy !== 1'b0) begin
            `uvm_fatal("LINK_DRIVER",
                       "Timeout: DUT did not return to IDLE")
        end

        // Return driver to idle
        @(negedge vif.clk);

        vif.tx_ready     = 1'b0;
        vif.inject_error = 1'b0;

        `uvm_info("LINK_DRIVER",
                  $sformatf(
                      "Transaction completed: sequence=%0d retransmissions=%0d",
                      req.sequence_num,
                      vif.retransmission_count),
                  UVM_MEDIUM)

    endtask


    // Driver run phase
    task run_phase(uvm_phase phase);

        ucie_transaction_item req;

        drive_idle();
        wait_for_reset();

        forever begin

            seq_item_port.get_next_item(req);

            drive_transaction(req);

            seq_item_port.item_done();

        end

    endtask

endclass

`endif
