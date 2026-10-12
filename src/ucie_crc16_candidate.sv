module ucie_crc16_candidate (
    input  logic [1023:0] message,
    output logic [15:0]   crc
);

    logic [15:0] crc_temp;
    logic        feedback;
    integer      i;

    always_comb begin
        crc_temp = 16'h0000;

        // Process message bits in byte order:
        // bit 0, bit 1, ... bit 7 of each byte.
        for (i = 0; i < 1024; i = i + 1) begin
            feedback = crc_temp[15] ^ message[i];

            crc_temp = {crc_temp[14:0], 1'b0};

            if (feedback)
                crc_temp = crc_temp ^ 16'h8005;
        end

        crc = crc_temp;
    end

endmodule