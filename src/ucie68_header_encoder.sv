// Code your design here
module ucie68b_header_encoder (
    input  logic       stack_id,
    input  logic [1:0] ack_nak_type,
    input  logic [7:0] sequence_num,
    output logic [7:0] header_byte0,
    output logic [7:0] header_byte1
);

    always_comb begin
        header_byte0 = 8'h00;
        header_byte1 = 8'h00;

        // Regular Streaming flit header
        header_byte0[7:6] = 2'b01;       // Protocol Layer flit
        header_byte0[5]   = stack_id;
        header_byte0[4]   = 1'b0;        // Regular header
        header_byte0[3:0] = sequence_num[7:4];

        header_byte1[7:6] = 2'b00;       // Regular header
        header_byte1[5:4] = ack_nak_type;
        header_byte1[3:0] = sequence_num[3:0];
    end

endmodule