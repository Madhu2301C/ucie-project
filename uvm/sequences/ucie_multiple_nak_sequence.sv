`ifndef UCIE_MULTIPLE_NAK_SEQUENCE_SV
`define UCIE_MULTIPLE_NAK_SEQUENCE_SV

class ucie_multiple_nak_sequence extends uvm_sequence #(ucie_transaction_item);

    `uvm_object_utils(ucie_multiple_nak_sequence)

    function new(string name = "ucie_multiple_nak_sequence");
        super.new(name);
    endfunction

    task body();

        ucie_transaction_item req;

        // ---------------------------------
        // STEP 1: Initial transmission + NAK #1
        // ---------------------------------

        req = ucie_transaction_item::type_id::create("initial_req");

        start_item(req);

        req.flit_data = {17{32'hA5A5_5A5A}};
        req.send_req = 1;
        req.tx_ready = 1;
        req.ack = 0;
        req.nak = 1;
        req.stall_cycles = 0;
        req.inject_crc_error = 0;
        req.corrupt_bit_index = 0;

        finish_item(req);

        // First replay is now accepted.
        // Controller returns to WAIT_ACK.

        // ---------------------------------
        // STEP 2: NAK #2
        // ---------------------------------

        req = ucie_transaction_item::type_id::create("second_nak_req");

        start_item(req);

        req.flit_data = '0;
        req.send_req = 0;
        req.tx_ready = 1;
        req.ack = 0;
        req.nak = 1;
        req.stall_cycles = 0;
        req.inject_crc_error = 0;
        req.corrupt_bit_index = 0;

        finish_item(req);

        // Second replay is now accepted.
        // Controller returns to WAIT_ACK.

        // ---------------------------------
        // STEP 3: Final ACK
        // ---------------------------------

        req = ucie_transaction_item::type_id::create("final_ack_req");

        start_item(req);

        req.flit_data = '0;
        req.send_req = 0;
        req.tx_ready = 1;
        req.ack = 1;
        req.nak = 0;
        req.stall_cycles = 0;
        req.inject_crc_error = 0;
        req.corrupt_bit_index = 0;

        finish_item(req);

    endtask

endclass

`endif
