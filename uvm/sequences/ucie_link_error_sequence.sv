`ifndef UCIE_LINK_ERROR_SEQUENCE_SV
`define UCIE_LINK_ERROR_SEQUENCE_SV

class ucie_link_error_sequence extends uvm_sequence #(ucie_transaction_item);

    `uvm_object_utils(ucie_link_error_sequence)

    // Constructor
    function new(string name = "ucie_link_error_sequence");
        super.new(name);
    endfunction


    // Sequence body
    virtual task body();

        ucie_transaction_item req;

        `uvm_info("LINK_ERROR_SEQ",
                  "Starting error injection link transaction",
                  UVM_MEDIUM)

        // Create transaction
        req = ucie_transaction_item::type_id::create("req");

        // Start transaction
        start_item(req);

        // Randomize transaction fields
        if (!req.randomize() with {
            inject_error == 1;
            sequence_num == 8'h02;
        }) begin
            `uvm_fatal("LINK_ERROR_SEQ",
                       "Transaction randomization failed")
        end

        // Display generated transaction
        `uvm_info("LINK_ERROR_SEQ",
                  $sformatf("Sequence Number = %0d", req.sequence_num),
                  UVM_MEDIUM)

        `uvm_info("LINK_ERROR_SEQ",
                  $sformatf("Payload = %h", req.payload),
                  UVM_HIGH)

        `uvm_info("LINK_ERROR_SEQ",
                  $sformatf("Error Injection = %0b", req.inject_error),
                  UVM_MEDIUM)

        // Send transaction to driver
        finish_item(req);

        `uvm_info("LINK_ERROR_SEQ",
                  "Error injection transaction sent to driver",
                  UVM_MEDIUM)

    endtask

endclass

`endif
