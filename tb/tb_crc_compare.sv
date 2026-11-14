`timescale 1ns/1ps
module tb_crc_compare();
    logic [1023:0] message;
    logic [15:0]   crc_candidate;
    logic [15:0]   crc_reference;

    ucie_crc16_candidate u_candidate (
        .message(message),
        .crc(crc_candidate)
    );

    ucie_crc16_reference u_reference (
        .message(message),
        .crc(crc_reference)
    );

    initial begin
        // Consistency check: both modules use the same recurrence.
        // Case 1: Zero message
        message = '0;
        #1;
        assert (crc_candidate === crc_reference)
            else $fatal(1, "CRC mismatch for zero message. Cand: %h, Ref: %h", crc_candidate, crc_reference);

        // Case 2: Bit 0
        message = '0;
        message[0] = 1'b1;
        #1;
        assert (crc_candidate === crc_reference)
            else $fatal(1, "CRC mismatch for message[0]. Cand: %h, Ref: %h", crc_candidate, crc_reference);

        // Case 3: Bit 8
        message = '0;
        message[8] = 1'b1;
        #1;
        assert (crc_candidate === crc_reference)
            else $fatal(1, "CRC mismatch for message[8]. Cand: %h, Ref: %h", crc_candidate, crc_reference);

        $display("Candidate and reference models agree.");
        $display("REGRESSION_PASS: tb_crc_compare");
        $finish;
    end
    initial begin #10000; $fatal(1, "FAIL: tb_crc_compare watchdog"); end
endmodule
