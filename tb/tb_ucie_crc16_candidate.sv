`timescale 1ns/1ps

module tb_ucie_crc16_candidate;

    logic [1023:0] message;
    logic [15:0]   crc;

    logic [1023:0] message_a;
    logic [1023:0] message_b;

    logic [15:0] crc_a;
    logic [15:0] crc_b;
    logic [15:0] crc_ab;

    // Main DUT for basic tests
    ucie_crc16_candidate dut (
        .message(message),
        .crc(crc)
    );

    // Additional candidate instances for linearity testing; not independent models
    ucie_crc16_candidate dut_a (
        .message(message_a),
        .crc(crc_a)
    );

    ucie_crc16_candidate dut_b (
        .message(message_b),
        .crc(crc_b)
    );

    ucie_crc16_candidate dut_ab (
        .message(message_a ^ message_b),
        .crc(crc_ab)
    );

    initial begin
        $display("Starting extended CRC tests");

        // Test 1: All-zero message
        message = '0;
        #1;

        if (crc !== 16'h0000)
            $fatal(1, "FAIL: zero-message CRC = %04h", crc);

        $display("PASS: zero-message CRC = %04h", crc);

        // Test 2: Single bit at message bit 0
        message = '0;
        message[0] = 1'b1;
        #1;

        if (crc !== 16'h8039)
            $fatal(1, "FAIL: bit-0 CRC expected 8039, got %04h", crc);

        $display("PASS: bit-0 CRC = %04h", crc);

        // Test 3: Single bit at message bit 8
        message = '0;
        message[8] = 1'b1;
        #1;

        if (crc !== 16'h0B00)
            $fatal(1, "FAIL: bit-8 CRC expected 0B00");

        $display("PASS: bit-8 CRC = %04h", crc);

        // Test 4: Repeatability
        message = '0;
        message[0] = 1'b1;
        #1;

        if (crc !== 16'h8039)
            $fatal(1, "FAIL: repeatability test");

        $display("PASS: repeatability");

        // Test 5: CRC linearity
        message_a = '0;
        message_b = '0;

        message_a[0]   = 1'b1;
        message_a[127] = 1'b1;

        message_b[8]   = 1'b1;
        message_b[300] = 1'b1;

        #1;

        if (crc_ab !== (crc_a ^ crc_b))
            $fatal(1, "FAIL: CRC linearity check");

        $display("PASS: CRC linearity");


	// Test 6: All 128 bytes set to FF
	message = {1024{1'b1}};
	#1;
if (crc !== 16'h002E)
    $fatal(1, "FAIL: all-FF CRC expected 002E, got %04h", crc);
$display("PASS: all-FF CRC = %04h", crc);

// Test 7: Incrementing byte pattern: 00, 01, ... 7F
message = '0;
for (integer b = 0; b < 128; b = b + 1)
    message[b*8 +: 8] = b[7:0];
#1;
if (crc !== 16'h249F)
    $fatal(1, "FAIL: incrementing CRC expected 249F, got %04h", crc);
$display("PASS: incrementing CRC = %04h", crc);

        $display("All seven extended CRC tests passed");
        $display("REGRESSION_PASS: tb_ucie_crc16_candidate");
        $finish;
    end

    initial begin #10000; $fatal(1, "FAIL: tb_ucie_crc16_candidate watchdog"); end
endmodule
