`timescale 1ns/1ps
module tb_ucie68b_flit_tx_mapping;

    logic         stack_id;
    logic [1:0]   ack_nak_type;
    logic [7:0]   sequence_num;
    logic [511:0] payload;
    logic [543:0] flit_out;

    logic [7:0]  header_byte0;
    logic [7:0]  header_byte1;
    logic [1023:0] expected_crc_message;
    logic [15:0] expected_crc;

    ucie68b_flit_tx dut (
        .stack_id     (stack_id),
        .ack_nak_type (ack_nak_type),
        .sequence_num (sequence_num),
        .payload      (payload),
        .flit_out     (flit_out)
    );

    // Independently reconstruct the expected input mapping.
    ucie68b_header_encoder expected_header (
        .stack_id     (stack_id),
        .ack_nak_type (ack_nak_type),
        .sequence_num (sequence_num),
        .header_byte0 (header_byte0),
        .header_byte1 (header_byte1)
    );

    ucie_crc16_candidate expected_crc_unit (
        .message (expected_crc_message),
        .crc     (expected_crc)
    );

    task automatic check_mapping;
        begin
            expected_crc_message = '0;
            expected_crc_message[7:0]    = header_byte0;
            expected_crc_message[15:8]   = header_byte1;
            expected_crc_message[527:16] = payload;

            #1;

            $display("---- CRC DEBUG ----");
            $display("TB header_byte0=%02h, header_byte1=%02h", header_byte0, header_byte1);
            $display("DUT header_byte0=%02h, header_byte1=%02h", dut.header_byte0, dut.header_byte1);
            $display("DUT CRC message [15:0] = %04h", dut.crc_message[15:0]);
            $display("EXP CRC message [15:0] = %04h", expected_crc_message[15:0]);
            $display("DUT CRC value          = %04h", dut.crc_value);
            $display("Expected CRC value     = %04h", expected_crc);
            $display("Flit CRC bytes         = %02h %02h", flit_out[543:536], flit_out[535:528]);

            if (dut.crc_message !== expected_crc_message)
                $fatal(1, "FAIL: TX and testbench CRC input messages differ");

            if (dut.crc_value !== expected_crc)
                $fatal(1, "FAIL: TX and testbench CRC values differ");

            if (flit_out[7:0] !== header_byte0)
                $fatal(1, "FAIL: header_byte0 mapping");

            if (flit_out[15:8] !== header_byte1)
                $fatal(1, "FAIL: header_byte1 mapping");

            if (flit_out[527:16] !== payload)
                $fatal(1, "FAIL: payload mapping");

            if (flit_out[535:528] !== expected_crc[7:0])
                $fatal(1, "FAIL: CRC low-byte mapping");

            if (flit_out[543:536] !== expected_crc[15:8]) begin
                $display("CRC High Byte Mapping Failure: Got %h, Expected %h", flit_out[543:536], expected_crc[15:8]);
                $fatal(1, "FAIL: CRC high-byte mapping");
            end

            if (expected_crc_message[1023:528] !== '0)
                $fatal(1, "FAIL: expected CRC padding is not zero");

            // Direct internal padding check
            if (dut.crc_message[1023:528] !== '0)
                $fatal(1, "FAIL: DUT CRC input padding is not zero");

            $display("PASS: header, payload, CRC placement, padding");
        end
    endtask

    initial begin
        stack_id     = 1'b0;
        ack_nak_type = 2'b00;
        sequence_num = 8'h00;
        payload      = '0;

        #1; // Wait for combinational expected_header to evaluate before task call
        check_mapping();

        stack_id     = 1'b1;
        ack_nak_type = 2'b10;
        sequence_num = 8'hA5;
        payload      = {64{8'hA5}};
        #1; // Wait for combinational logic to update
        check_mapping();

        stack_id     = 1'b0;
        ack_nak_type = 2'b01;
        sequence_num = 8'hFF;
        payload      = {64{8'hFF}};
        #1; // Wait for combinational logic to update
        check_mapping();

        $display("ALL FLIT MAPPING TESTS PASSED");
        $display("REGRESSION_PASS: tb_ucie68b_flit_tx_mapping");
        $finish;
    end

    initial begin #10000; $fatal(1, "FAIL: tb_ucie68b_flit_tx_mapping watchdog"); end
endmodule
