`timescale 1ns/1ps

module tb_crc_independent_vectors;

    logic [1023:0] message;
    logic [15:0] crc;

    integer i;

    ucie_crc16_candidate dut (
        .message(message),
        .crc(crc)
    );

    initial begin
        // Test 1: All zeros
        message = '0;
        #1;
        if (crc !== 16'h0000)
            $fatal(1, "All-zero test FAILED: %h", crc);

        // Test 2: All ones
        message = {128{8'hFF}};
        #1;
        if (crc !== 16'h002E)
            $fatal(1, "All-FF test FAILED: %h", crc);

        // Test 3: Alternating AA and 55 bytes
        for (i = 0; i < 128; i = i + 1)
            message[i*8 +: 8] = (i % 2 == 0) ? 8'hAA : 8'h55;
        #1;
        if (crc !== 16'hD4CC)
            $fatal(1, "AA/55 test FAILED: %h", crc);

        // Test 4: Alternating 55 and AA bytes
        for (i = 0; i < 128; i = i + 1)
            message[i*8 +: 8] = (i % 2 == 0) ? 8'h55 : 8'hAA;
        #1;
        if (crc !== 16'hD4E2)
            $fatal(1, "55/AA test FAILED: %h", crc);

        // Test 5: Walking one through byte positions
        for (i = 0; i < 128; i = i + 1)
            message[i*8 +: 8] = 8'h01 << (i % 8);
        #1;
        if (crc !== 16'hEF52)
            $fatal(1, "Walking-one test FAILED: %h", crc);

        // Test 6: Walking-one complements
        for (i = 0; i < 128; i = i + 1)
            message[i*8 +: 8] = ~(8'h01 << (i % 8));
        #1;
        if (crc !== 16'hEF7C)
            $fatal(1, "Walking-one complement test FAILED: %h", crc);

        // Test 7: Incrementing bytes 00 through 7F
        for (i = 0; i < 128; i = i + 1)
            message[i*8 +: 8] = i[7:0];
        #1;
        if (crc !== 16'h249F)
            $fatal(1, "Incrementing-byte test FAILED: %h", crc);

        $display("PASS: All 7 independent CRC vector tests passed.");
        $display("REGRESSION_PASS: tb_crc_independent_vectors");
        $finish;
    end

    initial begin #10000; $fatal(1, "FAIL: tb_crc_independent_vectors watchdog"); end
endmodule
