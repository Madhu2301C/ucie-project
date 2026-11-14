`ifndef UCIE_NORMAL_TX_ACK_SEQUENCE_SV
`define UCIE_NORMAL_TX_ACK_SEQUENCE_SV

// ============================================================================
// TC01: Normal Transmission Followed by ACK
// ============================================================================
// Objective:
// 1. Submit a new flit.
// 2. Complete initial transmission.
// 3. Receive ACK.
// 4. Verify the controller returns to IDLE.
//
// Expected behavior:
// IDLE -> SEND_NEW -> WAIT_ACK -> IDLE
// ============================================================================

class ucie_normal_tx_ack_sequence extends
    uvm_sequence #(ucie_transaction_item);

    `uvm_object_utils(ucie_normal_tx_ack_sequence)

    // Constructor
    function new(string name = "ucie_normal_tx_ack_sequence");

        super.new(name);

    endfunction


    // Sequence body
    task body();

        ucie_transaction_item req;

        `uvm_info("UCIE_NORMAL_TX_ACK_SEQUENCE",
                  "Starting Normal Transmission with ACK Test",
                  UVM_LOW)

        // Create transaction
        req = ucie_transaction_item::type_id::create("req");

        // Request sequencer permission
        start_item(req);

        // Configure transaction
        req.flit_data = {17{32'hA5A5_5A5A}};

        req.send_req = 1'b1;
        req.tx_ready = 1'b1;

        req.ack = 1'b1;
        req.nak = 1'b0;

        req.stall_cycles = 0;

        req.inject_crc_error = 1'b0;
        req.corrupt_bit_index = 0;

        // Send transaction to driver
        finish_item(req);

        `uvm_info("UCIE_NORMAL_TX_ACK_SEQUENCE",
                  "Normal Transmission with ACK Test Completed",
                  UVM_LOW)

    endtask

endclass

`endif
