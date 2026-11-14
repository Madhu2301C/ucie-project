`timescale 1ns/1ps
// Code your testbench here
// or browse Examples
module tb_ucie68b_header_encoder;

    logic       stack_id;
    logic [1:0] ack_nak_type;
    logic [7:0] sequence_num;

    logic [7:0] header_byte0;
    logic [7:0] header_byte1;

    ucie68b_header_encoder dut (
        .stack_id      (stack_id),
        .ack_nak_type  (ack_nak_type),
        .sequence_num  (sequence_num),
        .header_byte0  (header_byte0),
        .header_byte1  (header_byte1)
    );

    task automatic check_header(
        input logic       test_stack_id,
        input logic [1:0] test_type,
        input logic [7:0] test_seq,
        input logic [7:0] expected_byte0,
        input logic [7:0] expected_byte1
    );
        begin
            stack_id     = test_stack_id;
            ack_nak_type = test_type;
            sequence_num = test_seq;

            #1;

            if ((header_byte0 !== expected_byte0) ||
                (header_byte1 !== expected_byte1)) begin

                $fatal(1,
                    "FAIL: header stack=%0b type=%b seq=%h expected=%02h %02h actual=%02h %02h",
                    test_stack_id, test_type, test_seq,
                    expected_byte0, expected_byte1, header_byte0, header_byte1);
            end
            else begin
                $display("PASS: stack=%0b type=%b seq=%02h header=%02h %02h",
         test_stack_id, test_type, test_seq,
         header_byte0, header_byte1);
            end
        end
    endtask

    initial begin
        $display("Starting UCIe 68B header encoder tests");

        // Explicit sequence number: 0x12
        check_header(1'b0, 2'b00, 8'h12, 8'h41, 8'h02);

        // ACK encoding example: 0x12
        check_header(1'b0, 2'b01, 8'h12, 8'h41, 8'h12);

        // NAK field encoding example: 0x35
        check_header(1'b1, 2'b10, 8'h35, 8'h63, 8'h25);

        $display("All header encoder tests passed.");
        $display("REGRESSION_PASS: tb_ucie68b_header_encoder");
        $finish;
    end

    initial begin #10000; $fatal(1, "FAIL: tb_ucie68b_header_encoder watchdog"); end
endmodule
