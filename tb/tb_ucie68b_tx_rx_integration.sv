`timescale 1ns/1ps
module tb_ucie68b_tx_rx_integration;
    logic stack_id;
    logic [1:0] ack_nak_type;
    logic [7:0] sequence_num;
    logic [511:0] payload, payload_out;
    logic [543:0] flit_out, flit_in;
    logic [7:0] header_byte0, header_byte1;
    logic [15:0] calculated_crc, received_crc;
    logic crc_error, flit_valid;
    logic [1023:0] expected_message;
    integer i, j;
    integer seed = 32'h68b01234;
    ucie68b_flit_tx tx (.*);
    ucie68b_flit_rx rx (.*);
    initial begin
        for (j = 0; j < 256; j = j + 1) begin
            stack_id = j % 2;
            ack_nak_type = j % 4;
            sequence_num = j;
            for (i = 0; i < 16; i = i + 1) payload[i*32 +: 32] = $random(seed);
            #1; flit_in = flit_out; #1;
            expected_message = '0;
            expected_message[7:0] = {2'b01,stack_id,1'b0,sequence_num[7:4]};
            expected_message[15:8] = {2'b00,ack_nak_type,sequence_num[3:0]};
            expected_message[527:16] = payload;
            if (tx.crc_message !== expected_message ||
                rx.crc_message !== expected_message ||
                tx.crc_message !== rx.crc_message ||
                tx.crc_message[1023:528] !== '0 ||
                rx.crc_message[1023:528] !== '0)
                $fatal(1, "FAIL: full CRC message or zero padding %0d", j);
            if (flit_out[535:528] !== tx.crc_value[7:0] ||
                flit_out[543:536] !== tx.crc_value[15:8] ||
                received_crc[7:0] !== flit_out[535:528] ||
                received_crc[15:8] !== flit_out[543:536] ||
                calculated_crc !== tx.crc_value)
                $fatal(1, "FAIL: CRC byte order or TX/RX CRC %0d", j);
            if (crc_error !== 1'b0 || flit_valid !== 1'b1 || payload_out !== payload ||
                header_byte0 !== {2'b01,stack_id,1'b0,sequence_num[7:4]} ||
                header_byte1 !== {2'b00,ack_nak_type,sequence_num[3:0]} ||
                calculated_crc !== received_crc)
                $fatal(1, "FAIL: round trip %0d", j);
            flit_in[j % 544] = ~flit_in[j % 544]; #1;
            if (crc_error !== 1'b1 || flit_valid !== 1'b0)
                $fatal(1, "FAIL: corruption %0d", j);
        end
        $display("ALL TX/RX INTEGRATION TESTS PASSED: 256 round trips and corruptions");
        $display("REGRESSION_PASS: tb_ucie68b_tx_rx_integration");
        $finish;
    end
    initial begin #10000; $fatal(1, "FAIL: TX/RX integration timeout"); end
endmodule
