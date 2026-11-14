`ifndef UCIE_LINK_SEQUENCER_SV
`define UCIE_LINK_SEQUENCER_SV

class ucie_link_sequencer extends uvm_sequencer #(ucie_transaction_item);

    `uvm_component_utils(ucie_link_sequencer)

    function new(string name = "ucie_link_sequencer",
                 uvm_component parent = null);
        super.new(name, parent);
    endfunction

endclass

`endif
