`ifndef UCIE_RETRY_MONITOR_SV
`define UCIE_RETRY_MONITOR_SV

class ucie_retry_monitor extends uvm_monitor;

    `uvm_component_utils(ucie_retry_monitor)

    // Virtual interface
    virtual ucie_retry_if vif;

    // Analysis port
    uvm_analysis_port #(ucie_transaction_item) analysis_port;

    // Previous-cycle response values
    bit prev_ack;
    bit prev_nak;
    bit prev_timeout;

    // Constructor
    function new(string name = "ucie_retry_monitor",
                 uvm_component parent = null);

        super.new(name, parent);

        analysis_port = new("analysis_port", this);

        prev_ack = 0;
        prev_nak = 0;
        prev_timeout = 0;

    endfunction


    // Build phase
    function void build_phase(uvm_phase phase);

        super.build_phase(phase);

        if (!uvm_config_db #(virtual ucie_retry_if)::get(
                this, "", "vif", vif
            )) begin

            `uvm_fatal("RETRY_MONITOR",
                       "Virtual interface not found")

        end

    endfunction


    // Monitor DUT signals
    task run_phase(uvm_phase phase);

        ucie_transaction_item observed_item;

        bit ack_event;
        bit nak_event;
        bit timeout_event;

        forever begin

            @(posedge vif.clk);

            // Reset handling
            if (vif.rst_n !== 1'b1) begin

                prev_ack = 0;
                prev_nak = 0;
                prev_timeout = 0;

            end
            else begin

                // Detect response rising edges
                ack_event =
                    (vif.ack === 1'b1) && !prev_ack;

                nak_event =
                    (vif.nak === 1'b1) && !prev_nak;

                timeout_event =
                    (vif.timeout_pulse === 1'b1) &&
                    !prev_timeout;

                // Update previous-cycle values
                prev_ack = (vif.ack === 1'b1);
                prev_nak = (vif.nak === 1'b1);
                prev_timeout =
                    (vif.timeout_pulse === 1'b1);

                // Publish every valid transmission cycle,
                // or a newly observed response event.
                if ((vif.tx_valid === 1'b1) ||
                    ack_event ||
                    nak_event ||
                    timeout_event) begin

                    observed_item =
                        ucie_transaction_item::type_id::create(
                            "observed_item"
                        );

                    // Input-side observations
                    observed_item.send_req = vif.send_req;
                    observed_item.tx_ready = vif.tx_ready;

                    // Publish response events only once
                    observed_item.ack = ack_event;
                    observed_item.nak = nak_event;

                    // DUT output observations
                    observed_item.tx_valid = vif.tx_valid;
                    observed_item.tx_flit_out = vif.tx_flit_out;
                    observed_item.busy = vif.busy;
                    observed_item.retransmit = vif.retransmit;

                    observed_item.timeout_pulse =
                        timeout_event;

                    // Publish to scoreboard
                    analysis_port.write(observed_item);

                    // Monitor messages
                    if (timeout_event) begin

                        `uvm_info("RETRY_MONITOR",
                                  "Timeout event detected",
                                  UVM_MEDIUM)

                    end

                    if (ack_event && nak_event) begin

                        `uvm_info("RETRY_MONITOR",
                                  "Simultaneous ACK and NAK detected",
                                  UVM_MEDIUM)

                    end
                    else if (ack_event) begin

                        `uvm_info("RETRY_MONITOR",
                                  "ACK event detected",
                                  UVM_MEDIUM)

                    end
                    else if (nak_event) begin

                        `uvm_info("RETRY_MONITOR",
                                  "NAK event detected",
                                  UVM_MEDIUM)

                    end

                    if ((vif.tx_valid === 1'b1) &&
                        (vif.tx_ready === 1'b0)) begin

                        `uvm_info("RETRY_MONITOR",
                                  "Transmission stalled by backpressure",
                                  UVM_MEDIUM)

                    end

                    if ((vif.tx_valid === 1'b1) &&
                        (vif.tx_ready === 1'b1)) begin

                        `uvm_info("RETRY_MONITOR",
                                  "Transmission handshake observed",
                                  UVM_MEDIUM)

                    end

                end

            end

        end

    endtask

endclass

`endif
