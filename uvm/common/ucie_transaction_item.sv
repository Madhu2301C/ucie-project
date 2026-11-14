`timescale 1ns/1ps

// -----------------------------------------------------------------------------
// Common transaction item for UCIe RTL verification
// -----------------------------------------------------------------------------
// This is the shared data structure used by both TX/RX and Retry agents.
// It represents a complete logical flit and its associated control information.
// Header, payload, and CRC are derived fields from flit_data — they must agree
// with the complete flit and are not independently randomized.
//
// Layout:
//   Header : flit_data[15:0]
//   Payload: flit_data[527:16]
//   CRC    : flit_data[543:528]
// -----------------------------------------------------------------------------

class ucie_transaction_item extends uvm_sequence_item;

    // =====================================
    // 1. COMMON FLIT INFORMATION
    // =====================================

    rand bit [543:0] flit_data;
    rand bit [7:0]   sequence_num;
    rand bit [511:0] payload;
    rand bit         inject_error;

    // Derived fields
    bit [15:0]  header;
    bit [15:0]  crc;
    bit [511:0] flit_payload;


    // =====================================
    // 2. CONTROL INPUTS
    // =====================================

    rand bit send_req;
    rand bit tx_ready;
    rand bit ack;
    rand bit nak;


    // =====================================
    // 3. ERROR INJECTION
    // =====================================

    rand bit inject_crc_error;
    rand int unsigned corrupt_bit_index;

    rand int unsigned stall_cycles;


    // =====================================
    // RANDOMIZATION CONSTRAINTS
    // =====================================

    constraint c_corrupt_bit_range {
        corrupt_bit_index inside {[0:543]};
    }

    constraint c_stall_cycles_range {
        stall_cycles inside {[0:100]};
    }


    // =====================================
    // 4. OBSERVED OUTPUTS
    // =====================================

    logic tx_valid;
    logic [543:0] tx_flit_out;

    logic busy;
    logic retransmit;
    logic timeout_pulse;

    logic crc_error;
    logic flit_valid;

    logic done;
    logic crc_error_seen;
    logic [31:0] retransmission_count;
    logic [511:0] received_payload;


    // =====================================
    // 5. FACTORY REGISTRATION
    // =====================================

    `uvm_object_utils_begin(ucie_transaction_item)

        `uvm_field_int(flit_data, UVM_ALL_ON)
        `uvm_field_int(header, UVM_ALL_ON)
        `uvm_field_int(flit_payload, UVM_ALL_ON)
        `uvm_field_int(crc, UVM_ALL_ON)
        `uvm_field_int(sequence_num, UVM_ALL_ON)

        `uvm_field_int(send_req, UVM_ALL_ON)
        `uvm_field_int(tx_ready, UVM_ALL_ON)
        `uvm_field_int(ack, UVM_ALL_ON)
        `uvm_field_int(nak, UVM_ALL_ON)

        `uvm_field_int(inject_crc_error, UVM_ALL_ON)
        `uvm_field_int(corrupt_bit_index, UVM_ALL_ON)
        `uvm_field_int(stall_cycles, UVM_ALL_ON)
        `uvm_field_int(inject_error, UVM_ALL_ON)

        `uvm_field_int(tx_valid, UVM_ALL_ON)
        `uvm_field_int(tx_flit_out, UVM_ALL_ON)
        `uvm_field_int(busy, UVM_ALL_ON)
        `uvm_field_int(retransmit, UVM_ALL_ON)
        `uvm_field_int(timeout_pulse, UVM_ALL_ON)

        `uvm_field_int(crc_error, UVM_ALL_ON)
        `uvm_field_int(flit_valid, UVM_ALL_ON)
        `uvm_field_int(done, UVM_ALL_ON)
        `uvm_field_int(crc_error_seen, UVM_ALL_ON)
        `uvm_field_int(retransmission_count, UVM_ALL_ON)
        `uvm_field_int(received_payload, UVM_ALL_ON)

    `uvm_object_utils_end


    // =====================================
    // 6. CONSTRUCTOR
    // =====================================

    function new(string name = "ucie_transaction_item");

        super.new(name);

    endfunction


    // =====================================
    // 7. EXTRACT FLIT FIELDS
    // =====================================

    function void extract_flit_fields();

        header       = flit_data[15:0];
        flit_payload = flit_data[527:16];
        crc          = flit_data[543:528];

    endfunction

endclass
