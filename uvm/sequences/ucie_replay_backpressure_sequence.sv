`ifndef UCIE_REPLAY_BACKPRESSURE_SEQUENCE_SV
`define UCIE_REPLAY_BACKPRESSURE_SEQUENCE_SV

class ucie_replay_backpressure_sequence extends
    uvm_sequence #(ucie_transaction_item);

    `uvm_object_utils(ucie_replay_backpressure_sequence)

    function new(string name = "ucie_replay_backpressure_sequence");
        super.new(name);
    endfunction

    task body();

        ucie_transaction_item nak_req;
        ucie_transaction_item ack_req;

        // ---------------------------------
        // STEP 1: Initial transmission + NAK
        // Hold replay under backpressure
        // ---------------------------------

        nak_req = ucie_transaction_item::type_id::create("nak_req");

        start_item(nak_req);

        nak_req.flit_data = {17{32'hA5A5_5A5A}};
        nak_req.send_req = 1;
        nak_req.tx_ready = 1;
        nak_req.ack = 0;
        nak_req.nak = 1;

        nak_req.stall_cycles = 5;
        nak_req.inject_crc_error = 0;
        nak_req.corrupt_bit_index = 0;

        finish_item(nak_req);

        // Replay is accepted after backpressure is released.

        // ---------------------------------
        // STEP 2: Final ACK
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
