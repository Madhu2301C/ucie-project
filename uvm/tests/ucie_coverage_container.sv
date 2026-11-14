// Hierarchy-only container: intentionally no drivers or production scoreboard.
class ucie_coverage_container extends uvm_component;
    `uvm_component_utils(ucie_coverage_container)
    function new(string name, uvm_component parent=null);
        super.new(name,parent);
    endfunction
endclass
