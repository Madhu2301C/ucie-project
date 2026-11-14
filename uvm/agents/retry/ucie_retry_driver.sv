`ifndef UCIE_RETRY_DRIVER_SV
`define UCIE_RETRY_DRIVER_SV

// ============================================================================
// UCIe Retry Driver
// ============================================================================
// Supports:
// 1. New flit transmission
// 2. Initial transmission backpressure
// 3. ACK response
// 4. NAK and replay
// 5. Timeout and replay
// 6. Final ACK after replay
//
// Actual transmission handshake:
//              tx_valid && tx_ready
//
// IMPORTANT:
// Backpressure is applied only after the controller enters SEND_NEW.
// ============================================================================

class ucie_retry_driver extends
    uvm_driver #(ucie_transaction_item);

    `uvm_component_utils(ucie_retry_driver)

    virtual ucie_retry_if vif;

    localparam int MAX_WAIT_CYCLES = 100;


    // ========================================================================
    // CONSTRUCTOR
    // ========================================================================

    function new(string name = "ucie_retry_driver",
                 uvm_component parent = null);

        super.new(name, parent);

    endfunction


    // ========================================================================
    // BUILD PHASE
    // ========================================================================

    function void build_phase(uvm_phase phase);

        super.build_phase(phase);

        if (!uvm_config_db #(virtual ucie_retry_if)::get(
                this,
                "",
                "vif",
                vif
            )) begin

            `uvm_fatal("RETRY_DRIVER",
                       "Virtual interface not found")

        end

    endfunction


    // ========================================================================
    // DRIVE IDLE VALUES
    // ========================================================================

    task drive_idle();

        vif.send_req = 1'b0;
        vif.tx_flit  = '0;
        vif.tx_ready = 1'b0;
        vif.ack      = 1'b0;
        vif.nak      = 1'b0;

    endtask


    // ========================================================================
    // WAIT FOR RESET RELEASE
    // ========================================================================

    task wait_for_reset();

        wait (vif.rst_n === 1'b1);

        @(negedge vif.clk);

        `uvm_info("RETRY_DRIVER",
                  "Reset released",
                  UVM_LOW)

    endtask


    // ========================================================================
    // WAIT FOR ACTUAL TRANSMISSION ACCEPTANCE
    //
    // Both tx_valid and tx_ready must be HIGH at posedge.
    // ========================================================================

    task wait_for_acceptance(string operation_name);

        int unsigned cycles;

        cycles = 0;

        forever begin

            @(posedge vif.clk);

            if ((vif.tx_valid === 1'b1) &&
                (vif.tx_ready === 1'b1)) begin

                `uvm_info("RETRY_DRIVER",
                          $sformatf(
                              "%s handshake completed",
                              operation_name
                          ),
                          UVM_MEDIUM)

                break;

            end

            cycles++;

            if (cycles >= MAX_WAIT_CYCLES) begin

                `uvm_fatal("RETRY_DRIVER",
                           $sformatf(
                               "Timeout waiting for %s handshake",
                               operation_name
                           ))

            end

        end

    endtask


    // ========================================================================
    // WAIT FOR WAIT_ACK STATE
    //
    // Based on the current retry controller RTL:
    // busy     = 1
    // tx_valid = 0
    // ========================================================================

    task wait_for_wait_ack();

        int unsigned cycles;

        cycles = 0;

        forever begin

            @(negedge vif.clk);

            if ((vif.busy === 1'b1) &&
                (vif.tx_valid === 1'b0)) begin

                `uvm_info("RETRY_DRIVER",
                          "Controller entered WAIT_ACK",
                          UVM_MEDIUM)

                break;

            end

            cycles++;

            if (cycles >= MAX_WAIT_CYCLES) begin

                `uvm_fatal("RETRY_DRIVER",
                           "Timeout waiting for WAIT_ACK state")

            end

        end

    endtask


    // ========================================================================
    // WAIT FOR IDLE STATE
    // ========================================================================

    task wait_for_idle();

        int unsigned cycles;

        cycles = 0;

        forever begin

            @(negedge vif.clk);

            if (vif.busy === 1'b0) begin

                `uvm_info("RETRY_DRIVER",
                          "Controller returned to IDLE",
                          UVM_MEDIUM)

                break;

            end

            cycles++;

            if (cycles >= MAX_WAIT_CYCLES) begin

                `uvm_fatal("RETRY_DRIVER",
                           "Timeout waiting for IDLE state")

            end

        end

    endtask


    // ========================================================================
    // CONFIGURE INITIAL READY
    //
    // req.tx_ready = 1:
    //     tx_ready is HIGH immediately.
    //
    // req.tx_ready = 0:
    //     tx_ready remains LOW during SEND_NEW.
    //     It will be asserted after stall_cycles.
    // ========================================================================

    task configure_initial_ready(ucie_transaction_item req);

        if (req.tx_ready) begin

            vif.tx_ready = 1'b1;

            `uvm_info("RETRY_DRIVER",
                      "Initial tx_ready is HIGH",
                      UVM_MEDIUM)

        end
        else begin

            vif.tx_ready = 1'b0;

            `uvm_info("RETRY_DRIVER",
                      $sformatf(
                          "Initial tx_ready is LOW; requested stall=%0d cycles",
                          req.stall_cycles
                      ),
                      UVM_MEDIUM)

        end

    endtask


    // ========================================================================
    // RELEASE INITIAL BACKPRESSURE
    //
    // This task is called only after the controller enters SEND_NEW.
    // ========================================================================

    task release_initial_backpressure(
        ucie_transaction_item req
    );

        if (!req.tx_ready) begin

            // Hold tx_ready LOW while SEND_NEW is active.
            repeat (req.stall_cycles)
                @(negedge vif.clk);

            // Release backpressure.
            vif.tx_ready = 1'b1;

            `uvm_info("RETRY_DRIVER",
                      "Initial backpressure released",
                      UVM_MEDIUM)

        end

    endtask


    // ========================================================================
    // SUBMIT NEW FLIT
    //
    // Timing:
    // 1. Drive flit and ready policy.
    // 2. Assert send_req in IDLE.
    // 3. DUT captures request at posedge.
    // 4. Deassert send_req at negedge.
    // 5. Controller is now in SEND_NEW.
    // 6. Apply requested backpressure.
    // 7. Wait for tx_valid && tx_ready.
    // 8. Wait for WAIT_ACK.
    // ========================================================================

    task submit_new_flit(ucie_transaction_item req);

        // Drive data before request.
        vif.tx_flit = req.flit_data;

        // Set ready before entering SEND_NEW.
        configure_initial_ready(req);

        // Assert request.
        @(negedge vif.clk);

        vif.send_req = 1'b1;

        `uvm_info("RETRY_DRIVER",
                  "New flit request asserted",
                  UVM_MEDIUM)

        // IDLE captures send_req at this positive edge.
        @(posedge vif.clk);

        // Controller enters SEND_NEW after this edge.
        @(negedge vif.clk);

        vif.send_req = 1'b0;

        // Apply backpressure while SEND_NEW is active.
        release_initial_backpressure(req);

        // Wait for actual transmission handshake.
        wait_for_acceptance("INITIAL TRANSMISSION");

        // Controller enters WAIT_ACK after handshake.
        wait_for_wait_ack();

        // Keep ready HIGH for any subsequent replay.
        vif.tx_ready = 1'b1;

    endtask


    // ========================================================================
    // DRIVE ACK RESPONSE
    // ========================================================================

    task drive_ack_response();

        // Controller must already be in WAIT_ACK.
        @(negedge vif.clk);

        vif.ack = 1'b1;
        vif.nak = 1'b0;

        `uvm_info("RETRY_DRIVER",
                  "ACK asserted",
                  UVM_MEDIUM)

        // ACK is sampled at the next positive edge.
        @(negedge vif.clk);

        vif.ack = 1'b0;

        // Wait for transition to IDLE.
        wait_for_idle();

    endtask


    // ========================================================================
    // DRIVE ACK AND NAK TOGETHER (ACK PRIORITY)
    // ========================================================================

    task drive_ack_nak_response();

        // Assert ACK and NAK together
        @(negedge vif.clk);
        vif.ack = 1'b1;
        vif.nak = 1'b1;

        // Deassert both signals
        @(negedge vif.clk);
        vif.ack = 1'b0;
        vif.nak = 1'b0;

        // ACK priority should return controller to IDLE
        wait_for_idle();

    endtask


    // ========================================================================
    // DRIVE NAK AND WAIT FOR REPLAY
    // ========================================================================

    task drive_nak_response(ucie_transaction_item req);

        // Apply backpressure while entering replay
        @(negedge vif.clk);
        vif.tx_ready = 1'b0;
        vif.nak      = 1'b1;

        // NAK is sampled by the DUT
        @(negedge vif.clk);
        vif.nak = 1'b0;

        // Hold replay until the requested stall duration expires
        repeat (req.stall_cycles) begin
            @(negedge vif.clk);
        end

        // Release backpressure
        vif.tx_ready = 1'b1;

        // Wait for replay handshake and return to WAIT_ACK
        wait_for_acceptance("NAK replay");
        wait_for_wait_ack();

    endtask


    // ========================================================================
    // WAIT FOR TIMEOUT AND AUTOMATIC REPLAY
    // ========================================================================

    task wait_for_timeout_replay();

        int unsigned cycles;

        cycles = 0;

        // Allow replay to be accepted.
        vif.tx_ready = 1'b1;

        `uvm_info("RETRY_DRIVER",
                  "Waiting for timeout pulse",
                  UVM_MEDIUM)

        forever begin

            @(negedge vif.clk);

            if (vif.timeout_pulse === 1'b1) begin

                `uvm_info("RETRY_DRIVER",
                          "Timeout pulse detected",
                          UVM_MEDIUM)

                break;

            end

            cycles++;

            if (cycles >= MAX_WAIT_CYCLES) begin

                `uvm_fatal("RETRY_DRIVER",
                           "Timeout pulse not detected")

            end

        end

        // Controller transitions to SEND_REPLAY.
        wait_for_acceptance("TIMEOUT REPLAY");

        // Replay handshake returns controller to WAIT_ACK.
        wait_for_wait_ack();

    endtask


    // ========================================================================
    // PROCESS ONE TRANSACTION
    // ========================================================================

    task process_transaction(ucie_transaction_item req);


        // --------------------------------------------------------------------
        // CASE 1: New flit request
        // --------------------------------------------------------------------

        if (req.send_req) begin

            submit_new_flit(req);

        end

        // --------------------------------------------------------------------
        // CASE 2: Response to an existing pending flit
        // --------------------------------------------------------------------

        else begin

            if (!req.ack && !req.nak) begin

                `uvm_fatal("RETRY_DRIVER",
                           "Response transaction requires ACK or NAK")

            end

            // Wait for the existing flit to reach WAIT_ACK.
            wait_for_wait_ack();

        end


        // --------------------------------------------------------------------
        // CASE 3: ACK / NAK / TIMEOUT
        // --------------------------------------------------------------------

        if (req.ack && req.nak) begin

            drive_ack_nak_response();

        end
        else if (req.ack) begin

            drive_ack_response();

        end
        else if (req.nak) begin

            drive_nak_response(req);

        end
        else begin

            // No ACK or NAK: wait for timeout and automatic replay.
            wait_for_timeout_replay();

        end

    endtask


    // ========================================================================
    // RUN PHASE
    // ========================================================================

    task run_phase(uvm_phase phase);

        ucie_transaction_item req;

        drive_idle();

        wait_for_reset();

        `uvm_info("RETRY_DRIVER",
                  "UCIe Retry Driver Started",
                  UVM_LOW)

        forever begin

            // Request next sequence item.
            seq_item_port.get_next_item(req);

            `uvm_info("RETRY_DRIVER",
                      "Transaction received",
                      UVM_MEDIUM)

            // Execute complete requested operation.
            process_transaction(req);

            // Complete only after the operation finishes.
            seq_item_port.item_done();

            `uvm_info("RETRY_DRIVER",
                      "Transaction completed",
                      UVM_MEDIUM)

        end

    endtask

endclass

`endif
