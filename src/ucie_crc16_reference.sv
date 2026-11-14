module ucie_crc16_reference (
    input  logic [1023:0] message,
    output logic [15:0]   crc
);

    logic [15:0] crc_temp;
    logic        feedback;
    integer      byte_idx;
    integer      bit_idx;

    always_comb begin
        crc_temp = 16'h0000;
        feedback = 1'b0;

        // UCIe 1.1: process all 128 message bytes.
        // Within each byte, process bit 0 through bit 7.
        // The CRC-16 algorithm here must process bits in the same order
        // as the hardware's expected serial feed.
        for (byte_idx = 0; byte_idx < 128; byte_idx = byte_idx + 1) begin
            for (bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1) begin
                // Input bits: message[byte*8 + bit]
                // Polynomial: x^16 + x^15 + x^2 + 1
                feedback = crc_temp[15] ^ message[byte_idx * 8 + bit_idx];
                crc_temp = {crc_temp[14:0], 1'b0};
                if (feedback)
                    crc_temp = crc_temp ^ 16'h8005;
            end
        end

        crc = crc_temp;
    end

endmodule
