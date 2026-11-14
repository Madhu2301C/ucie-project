// ============================================================================
// UCIe Retry Agent
// ============================================================================
// UVM agent for the retry controller DUT.
// Instantiates:
//   1. Parameterized UVM sequencer
//   2. Retry driver
//   3. Retry monitor
//
// The driver is connected to the sequencer in connect_phase.
// ============================================================================

class ucie_retry_agent extends uvm_agent;

    `uvm_component_utils(ucie_retry_agent)

    // Component handles
    uvm_sequencer #(ucie_transaction_item) ucie_retry_seqr;

    ucie_retry_driver  driver;
    ucie_retry_monitor monitor;


    // Constructor
    function new(string name = "ucie_retry_agent",
                 uvm_component parent = null);

        super.new(name, parent);

    endfunction


    // Build phase
    function void build_phase(uvm_phase phase);

        super.build_phase(phase);

        // Monitor is always created
        monitor = ucie_retry_monitor::type_id::create(
            "monitor", this
        );

        // Create sequencer and driver for active agent
        if (get_is_active() == UVM_ACTIVE) begin

            ucie_retry_seqr = uvm_sequencer#(
                ucie_transaction_item
            )::type_id::create(
                "ucie_retry_seqr", this
            );

            driver = ucie_retry_driver::type_id::create(
                "driver", this
            );

        end

        `uvm_info("RETRY_AGENT",
                  "Retry Agent Build Phase Completed",
                  UVM_MEDIUM)

    endfunction


    // Connect phase
    function void connect_phase(uvm_phase phase);

        super.connect_phase(phase);

        // Connect driver to sequencer
        if (get_is_active() == UVM_ACTIVE) begin

            driver.seq_item_port.connect(
                ucie_retry_seqr.seq_item_export
            );

        end

        `uvm_info("RETRY_AGENT",
                  "Retry Agent Connections Completed",
                  UVM_MEDIUM)

    endfunction

endclass
