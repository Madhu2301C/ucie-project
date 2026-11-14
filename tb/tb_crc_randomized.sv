`timescale 1ns/1ps
module tb_crc_randomized();
    logic [1023:0] message;
    logic [15:0] crc_candidate, crc_reference;
    integer i;
    integer seed = 32'h68b01234;

    ucie_crc16_candidate u_candidate (.message(message), .crc(crc_candidate));
    ucie_crc16_reference u_reference (.message(message), .crc(crc_reference));

    initial begin
        for (i = 0; i < 1000; i = i + 1) begin
            // Generate random 1024-bit message
            message = {
                $random(seed), $random(seed), $random(seed), $random(seed),
                $random(seed), $random(seed), $random(seed), $random(seed),
                $random(seed), $random(seed), $random(seed), $random(seed),
                $random(seed), $random(seed), $random(seed), $random(seed),
                $random(seed), $random(seed), $random(seed), $random(seed),
                $random(seed), $random(seed), $random(seed), $random(seed),
                $random(seed), $random(seed), $random(seed), $random(seed),
                $random(seed), $random(seed), $random(seed), $random(seed)
            };
            #1;
            assert (crc_candidate === crc_reference)
                else $fatal(1, "Mismatch on iteration %0d", i);
        end
        $display("Passed 1000 model-consistency vectors; initial seed=68b01234.");
        $display("REGRESSION_PASS: tb_crc_randomized");
        $finish;
    end
    initial begin #10000; $fatal(1, "FAIL: tb_crc_randomized watchdog"); end
endmodule
