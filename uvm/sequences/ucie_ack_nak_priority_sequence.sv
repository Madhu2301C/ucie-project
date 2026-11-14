`ifndef UCIE_ACK_NAK_PRIORITY_SEQUENCE_SV
`define UCIE_ACK_NAK_PRIORITY_SEQUENCE_SV

class ucie_ack_nak_priority_sequence extends uvm_sequence #(ucie_transaction_item);

    `uvm_object_utils(ucie_ack_nak_priority_sequence)

    function new(string name = "ucie_ack_nak_priority_sequence");
        super.new(name);
    endfunction

    task body();

        ucie_transaction_item req;

        req = ucie_transaction_item::type_id::create("req");

        start_item(req);

        // Initial flit
        req.flit_data = {17{32'hA5A5_5A5A}};

        req.send_req = 1;
        req.tx_ready = 1;

        // Simultaneous response
        req.ack = 1;
        req.nak = 1;

        req.stall_cycles = 0;
        req.inject_crc_error = 0;
        req.corrupt_bit_index = 0;

        finish_item(req);

    endtask

endclass

`endif
