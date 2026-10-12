module ucie68b_flit_tx (
    input  logic        stack_id,
    input  logic [1:0]  ack_nak_type,
    input  logic [7:0]  sequence_num,
    input  logic [511:0] payload,

    output logic [543:0] flit_out
);

    logic [7:0] header_byte0;
    logic [7:0] header_byte1;
    logic [1023:0] crc_message;
    logic [15:0] crc_value;

    // Header encoder
    ucie68b_header_encoder u_header (
        .stack_id     (stack_id),
        .ack_nak_type (ack_nak_type),
        .sequence_num (sequence_num),
        .header_byte0 (header_byte0),
        .header_byte1 (header_byte1)
    );

    // CRC message: header + payload + zero padding
    always_comb begin
        crc_message = '0;

        crc_message[7:0]    = header_byte0;
        crc_message[15:8]   = header_byte1;
        crc_message[527:16] = payload;
    end

    // CRC candidate
    ucie_crc16_candidate u_crc (
        .message (crc_message),
        .crc     (crc_value)
    );

    // Flit byte order: header, payload, CRC
    always_comb begin
        flit_out = '0;

        flit_out[7:0]     = header_byte0;
        flit_out[15:8]    = header_byte1;
        flit_out[527:16]  = payload;
        flit_out[535:528] = crc_value[7:0];
        flit_out[543:536] = crc_value[15:8];
    end

endmodule