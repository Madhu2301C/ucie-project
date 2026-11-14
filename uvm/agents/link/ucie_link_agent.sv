`ifndef UCIE_LINK_AGENT_SV
`define UCIE_LINK_AGENT_SV

class ucie_link_agent extends uvm_agent;

    `uvm_component_utils(ucie_link_agent)

    ucie_link_sequencer sequencer;
    ucie_link_driver    driver;
    ucie_link_monitor   monitor;

    function new(string name = "ucie_link_agent",
                 uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        monitor = ucie_link_monitor::type_id::create(
            "monitor", this
        );

        if (get_is_active() == UVM_ACTIVE) begin
            sequencer = ucie_link_sequencer::type_id::create(
                "sequencer", this
            );

            driver = ucie_link_driver::type_id::create(
                "driver", this
            );
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        if (get_is_active() == UVM_ACTIVE) begin
            driver.seq_item_port.connect(
                sequencer.seq_item_export
            );
        end
    endfunction

endclass

`endif
