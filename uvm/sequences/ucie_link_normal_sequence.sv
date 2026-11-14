`ifndef UCIE_LINK_NORMAL_SEQUENCE_SV
`define UCIE_LINK_NORMAL_SEQUENCE_SV

class ucie_link_normal_sequence extends uvm_sequence #(ucie_transaction_item);

    `uvm_object_utils(ucie_link_normal_sequence)

    function new(string name = "ucie_link_normal_sequence");
        super.new(name);
    endfunction

    task body();
        ucie_transaction_item req;

        req = ucie_transaction_item::type_id::create("req");

        start_item(req);

        if (!req.randomize() with {
            inject_error == 0;
            sequence_num == 8'h01;
        }) begin
            `uvm_fatal("LINK_SEQ", "Normal transaction randomization failed")
        end

        finish_item(req);

        `uvm_info("LINK_SEQ",
                  "Normal link transaction completed",
                  UVM_MEDIUM)
    endtask

endclass

`endif
