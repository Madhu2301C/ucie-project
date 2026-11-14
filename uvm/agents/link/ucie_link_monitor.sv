`ifndef UCIE_LINK_MONITOR_SV
`define UCIE_LINK_MONITOR_SV

class ucie_link_monitor extends uvm_monitor;

    `uvm_component_utils(ucie_link_monitor)

    virtual ucie_link_if vif;

    uvm_analysis_port #(ucie_transaction_item) analysis_port;

    bit previous_done;
    bit previous_crc_error;

    // Preserve transaction context between handshake and completion
    logic [511:0] active_payload;
    logic [7:0]   active_sequence_num;
    bit           active_inject_error;
    bit           active_transaction_valid;


    function new(string name = "ucie_link_monitor",
                 uvm_component parent = null);

        super.new(name, parent);

        analysis_port = new("analysis_port", this);

        previous_done = 0;
        previous_crc_error = 0;

        active_payload = '0;
        active_sequence_num = '0;
        active_inject_error = 0;
        active_transaction_valid = 0;

    endfunction


    // Get virtual interface
    function void build_phase(uvm_phase phase);

        super.build_phase(phase);

        if (!uvm_config_db #(virtual ucie_link_if)::get(
                this, "", "vif", vif)) begin

            `uvm_fatal("LINK_MONITOR",
                       "ucie_link_if virtual interface not received")
        end

    endfunction


    // Monitor DUT activity
    task run_phase(uvm_phase phase);

        ucie_transaction_item item;

        bit handshake_event;
        bit done_event;
        bit crc_error_event;

        // Pre-NBA sampled values
        logic sampled_tx_valid;
        logic sampled_tx_ready;
        logic sampled_send_req;
        logic [511:0] sampled_payload;
        logic [7:0] sampled_sequence_num;
        bit sampled_inject_error;

        forever begin

            @(posedge vif.clk);

            if (!vif.rst_n) begin

                previous_done = 0;
                previous_crc_error = 0;

                active_payload = '0;
                active_sequence_num = '0;
                active_inject_error = 0;
                active_transaction_valid = 0;

            end
            else begin

                // -----------------------------------------
                // 1. Capture handshake and inputs BEFORE NBA
                // -----------------------------------------

                sampled_tx_valid = vif.tx_valid;
                sampled_tx_ready = vif.tx_ready;

                sampled_send_req = vif.send_req;
                sampled_payload = vif.payload;
                sampled_sequence_num = vif.sequence_num;
                sampled_inject_error = vif.inject_error;

                handshake_event =
                    (sampled_tx_valid === 1'b1) &&
                    (sampled_tx_ready === 1'b1);

                // Preserve context when a transmission is accepted
                if (handshake_event) begin

                    active_payload = sampled_payload;
                    active_sequence_num = sampled_sequence_num;
                    active_inject_error = sampled_inject_error;
                    active_transaction_valid = 1;

                end

                // -----------------------------------------
                // 2. Wait for registered outputs to update
                // -----------------------------------------

                #1;

                // -----------------------------------------
                // 3. Detect registered output events
                // -----------------------------------------

                done_event =
                    (vif.done === 1'b1) &&
                    (previous_done == 0);

                crc_error_event =
                    (vif.crc_error_seen === 1'b1) &&
                    (previous_crc_error == 0);

                previous_done =
                    (vif.done === 1'b1);

                previous_crc_error =
                    (vif.crc_error_seen === 1'b1);

                // -----------------------------------------
                // 4. Publish observed events
                // -----------------------------------------

                if (handshake_event ||
                    crc_error_event ||
                    done_event) begin

                    item = ucie_transaction_item::type_id::create(
                        "item"
                    );

                    // Transaction context
                    if (active_transaction_valid) begin

                        item.payload = active_payload;
                        item.sequence_num = active_sequence_num;
                        item.inject_error = active_inject_error;

                    end
                    else begin

                        item.payload = sampled_payload;
                        item.sequence_num = sampled_sequence_num;
                        item.inject_error = sampled_inject_error;

                    end

                    item.send_req = sampled_send_req;

                    // Handshake values captured before NBA
                    item.tx_valid = sampled_tx_valid;
                    item.tx_ready = sampled_tx_ready;

                    // Registered DUT outputs sampled after NBA
                    item.busy = vif.busy;
                    item.done = vif.done;
                    item.crc_error_seen = vif.crc_error_seen;

                    item.retransmit = vif.retransmit;

                    item.retransmission_count =
                        vif.retransmission_count;

                    item.received_payload =
                        vif.received_payload;

                    `uvm_info("LINK_MONITOR",
                              $sformatf(
                                  "Observed: handshake=%0b CRC_event=%0b done_event=%0b CRC_error=%0b retries=%0d",
                                  handshake_event,
                                  crc_error_event,
                                  done_event,
                                  item.crc_error_seen,
                                  item.retransmission_count),
                              UVM_MEDIUM)

                    analysis_port.write(item);

                end

            end

        end

    endtask

endclass

`endif