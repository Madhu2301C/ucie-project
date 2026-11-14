// ============================================================================
// UCIe Retry Sequencer
// ============================================================================
// UVM sequencer for the retry agent. Generates ucie_transaction_item sequences
// for driving the retry controller DUT.
// ============================================================================

class ucie_retry_sequencer extends uvm_sequencer #(ucie_transaction_item);

    `uvm_component_utils(ucie_retry_sequencer)

    // Constructor
    function new(string name = "ucie_retry_sequencer",
                 uvm_component parent = null);

        super.new(name, parent);

    endfunction

endclass
