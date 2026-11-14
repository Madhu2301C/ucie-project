`ifndef UCIE_TIMEOUT_REPLAY_SEQUENCE_SV
`define UCIE_TIMEOUT_REPLAY_SEQUENCE_SV

class ucie_timeout_replay_sequence extends uvm_sequence #(ucie_transaction_item);

    `uvm_object_utils(ucie_timeout_replay_sequence)

    function new(string name = "ucie_timeout_replay_sequence");
        super.new(name);
    endfunction

    task body();

        ucie_transaction_item timeout_req;
        ucie_transaction_item ack_req;

        // ---------------------------------
        // STEP 1: Send flit and wait for timeout
        // ---------------------------------

        timeout_req = ucie_transaction_item::type_id::create("timeout_req");

        start_item(timeout_req);

        timeout_req.flit_data = {17{32'hA5A5_5A5A}};
        timeout_req.send_req = 1;
        timeout_req.tx_ready = 1;
        timeout_req.ack = 0;
        timeout_req.nak = 0;
        timeout_req.stall_cycles = 0;
        timeout_req.inject_crc_error = 0;
        timeout_req.corrupt_bit_index = 0;

        finish_item(timeout_req);

        // Driver returns after timeout replay is accepted
        // and controller returns to WAIT_ACK.

        // ---------------------------------
        // STEP 2: Send final ACK
        // ---------------------------------

        ack_req = ucie_transaction_item::type_id::create("ack_req");

        start_item(ack_req);

        ack_req.flit_data = '0;
        ack_req.send_req = 0;
        ack_req.tx_ready = 1;
        ack_req.ack = 1;
        ack_req.nak = 0;
        ack_req.stall_cycles = 0;
        ack_req.inject_crc_error = 0;
        ack_req.corrupt_bit_index = 0;

        finish_item(ack_req);

    endtask

endclass

`endif
