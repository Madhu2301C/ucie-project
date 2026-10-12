module ucie68b_flit_rx (
    input  logic [543:0] flit_in,

    output logic [7:0]   header_byte0,
    output logic [7:0]   header_byte1,
    output logic [511:0] payload_out,
    output logic [15:0]  calculated_crc,
    output logic [15:0]  received_crc,
    output logic         crc_error,
    output logic         flit_valid
);

    logic [1023:0] crc_message;

    // Extract received fields
    always_comb begin
        header_byte0 = flit_in[7:0];
        header_byte1 = flit_in[15:8];

        payload_out  = flit_in[527:16];

        received_crc[7:0]  = flit_in[535:528];
        received_crc[15:8] = flit_in[543:536];

        // Build 128-byte CRC message
        crc_message = '0;
        crc_message[7:0]    = header_byte0;
        crc_message[15:8]   = header_byte1;
        crc_message[527:16] = payload_out;

        crc_error = (calculated_crc != received_crc);
        flit_valid = !crc_error;
    end

    // Recalculate CRC
    ucie_crc16_candidate u_crc (
        .message (crc_message),
        .crc     (calculated_crc)
    );

endmodule