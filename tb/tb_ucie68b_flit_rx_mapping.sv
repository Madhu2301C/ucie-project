`timescale 1ns/1ps
module tb_ucie68b_flit_rx_mapping;
    logic [543:0] flit_in, good_flit;
    logic [7:0] header_byte0, header_byte1;
    logic [511:0] payload_out;
    logic [15:0] calculated_crc, received_crc;
    logic crc_error, flit_valid;
    logic [1023:0] message;
    logic [15:0] expected_crc;
    integer i, j, checks;
    ucie68b_flit_rx dut (.*);
    ucie_crc16_reference reference_crc (.message(message), .crc(expected_crc));
    task automatic status(input bit error_expected);
        #1;
        if (crc_error !== error_expected || flit_valid !== !error_expected)
            $fatal(1, "FAIL: RX status check %0d error=%b valid=%b", checks, crc_error, flit_valid);
        checks = checks + 1;
    endtask
    initial begin
        checks = 0;
        for (j = 0; j < 20; j = j + 1) begin
            message = '0;
            for (i = 0; i < 66; i = i + 1)
                message[i*8 +: 8] = (j == 0) ? 0 : (i*13 + j*29);
            #1;
            good_flit = {expected_crc, message[527:0]};
            flit_in = good_flit;
            status(0);
            if ({header_byte1,header_byte0} !== message[15:0] ||
                payload_out !== message[527:16] || received_crc !== expected_crc ||
                calculated_crc !== expected_crc || dut.crc_message !== message)
                $fatal(1, "FAIL: RX mapping/padding vector %0d", j);
        end
        // Exhaust every wire bit for corruption and both four-state values.
        for (i = 0; i < 544; i = i + 1) begin
            flit_in = good_flit; flit_in[i] = ~good_flit[i]; status(1);
            flit_in = good_flit; flit_in[i] = 1'bx; status(1);
            flit_in = good_flit; flit_in[i] = 1'bz; status(1);
            flit_in = good_flit; status(0);
        end
        force dut.calculated_crc = 16'hxxxx; status(1);
        release dut.calculated_crc;
        // Change input to trigger CRC reevaluation after release.
        flit_in = '0; #1; flit_in = good_flit; status(0);
        $display("ALL RX MAPPING TESTS PASSED: %0d status checks", checks);
        $display("REGRESSION_PASS: tb_ucie68b_flit_rx_mapping");
        $finish;
    end
    initial begin #10000; $fatal(1, "FAIL: RX mapping timeout"); end
endmodule
