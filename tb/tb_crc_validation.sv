`timescale 1ns/1ps
module tb_crc_validation();
    logic [1023:0] message;
    logic [15:0] calculated_crc;

    // Instantiate your candidate
    ucie_crc16_candidate dut (
        .message(message),
        .crc(calculated_crc)
    );

    // Local expected values for the current CRC convention; not official golden vectors.
    initial begin
        // Case 1: All zeros with zero initialization.
        message = '0;
        #10;
        if (calculated_crc !== 16'h0000) $fatal(1, "FAIL: zero CRC expected 0000, got %h", calculated_crc);

        // Case 2: Message bit 0 set; local expected CRC is 8039.
        // This checks the implemented convention, not official UCIe conformance.
        message = 1024'h0000_0000_0000_0000_0000_0000_0000_0001;
        #10;
        if (calculated_crc !== 16'h8039) $fatal(1, "FAIL: bit-0 CRC expected 8039, got %h", calculated_crc);

        $display("REGRESSION_PASS: tb_crc_validation");
        $finish;
    end
    initial begin #10000; $fatal(1, "FAIL: tb_crc_validation watchdog"); end
endmodule
