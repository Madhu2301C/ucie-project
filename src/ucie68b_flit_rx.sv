
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

    // ------------------------------------------------
    // Extract received fields and construct CRC message
    // ------------------------------------------------
    always_comb begin

        // Extract header
        header_byte0 = flit_in[7:0];
        header_byte1 = flit_in[15:8];

        // Extract payload
        payload_out = flit_in[527:16];

        // Extract received CRC (little-endian byte order)
        received_crc[7:0]  = flit_in[535:528];
        received_crc[15:8] = flit_in[543:536];

        // Initialize complete 128-byte CRC message
        // Upper padding bits remain zero
        crc_message = '0;

        // Insert header and payload
        crc_message[7:0]    = header_byte0;
        crc_message[15:8]   = header_byte1;
        crc_message[527:16] = payload_out;

    end

    // ------------------------------------------------
    // CRC error detection and flit validity
    // ------------------------------------------------
    always_comb begin

        // Default CRC comparison
        crc_error = (calculated_crc != received_crc);

        // Simulation-only X/Z detection
        // $isunknown detects any X or Z bit
        // Synthesis tools ignore this simulation-only block

        // synthesis translate_off
        if ($isunknown(crc_message) ||
            $isunknown(received_crc) ||
            $isunknown(calculated_crc)) begin

            crc_error = 1'b1;

        end
        // synthesis translate_on

        // A flit is valid only when CRC comparison passes
        // and no unknown values are detected
        flit_valid = !crc_error;

    end

    // ------------------------------------------------
    // CRC recalculation
    // ------------------------------------------------
    ucie_crc16_candidate u_crc (
        .message (crc_message),
        .crc     (calculated_crc)
    );

endmodule