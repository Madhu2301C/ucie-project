`ifndef UCIE_NAK_REPLAY_SEQUENCE_SV
`define UCIE_NAK_REPLAY_SEQUENCE_SV

// ============================================================================
// TC02: NAK Detection and Flit Replay
// ============================================================================
// Objective:
// 1. Transmit a new flit.
// 2. Receive NAK.
// 3. Replay the previously transmitted flit.
// 4. Receive final ACK.
// 5. Verify controller returns to IDLE.
//
// Expected behavior:
// IDLE -> SEND_NEW -> WAIT_ACK -> SEND_REPLAY
//      -> WAIT_ACK -> IDLE
// ============================================================================

class ucie_nak_replay_sequence extends
    uvm_sequence #(ucie_transaction_item);

    `uvm_object_utils(ucie_nak_replay_sequence)

    // Constructor
    function new(string name = "ucie_nak_replay_sequence");

        super.new(name);

    endfunction


    task body();

        ucie_transaction_item nak_req;
        ucie_transaction_item ack_req;

        `uvm_info("UCIE_NAK_REPLAY_SEQUENCE",
                  "Starting NAK and Replay Test",
                  UVM_LOW)


        // ================================================================
        // STEP 1: Initial transmission followed by NAK
        // ================================================================

        nak_req = ucie_transaction_item::type_id::create(
            "nak_req"
        );

        start_item(nak_req);

        nak_req.flit_data = {17{32'hA5A5_5A5A}};

        nak_req.send_req = 1'b1;
        nak_req.tx_ready = 1'b1;

        nak_req.ack = 1'b0;
        nak_req.nak = 1'b1;

        nak_req.stall_cycles = 0;

        nak_req.inject_crc_error = 1'b0;
        nak_req.corrupt_bit_index = 0;

        finish_item(nak_req);

        `uvm_info("UCIE_NAK_REPLAY_SEQUENCE",
                  "Initial Transmission and NAK Processing Completed",
                  UVM_MEDIUM)


        // ================================================================
        // STEP 2: Final ACK after replay
        // ================================================================

        ack_req = ucie_transaction_item::type_id::create(
            "ack_req"
        );

        start_item(ack_req);

        ack_req.flit_data = '0;

        ack_req.send_req = 1'b0;
        ack_req.tx_ready = 1'b1;

        ack_req.ack = 1'b1;
        ack_req.nak = 1'b0;

        ack_req.stall_cycles = 0;

        ack_req.inject_crc_error = 1'b0;
        ack_req.corrupt_bit_index = 0;

        finish_item(ack_req);

        `uvm_info("UCIE_NAK_REPLAY_SEQUENCE",
                  "Final ACK Received; NAK Replay Test Completed",
                  UVM_LOW)

    endtask

endclass

`endif
