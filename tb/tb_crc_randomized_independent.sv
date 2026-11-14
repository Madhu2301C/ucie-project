`timescale 1ns/1ps
module tb_crc_randomized_independent;
    logic [1023:0] message;
    logic [15:0] crc;
    logic [15:0] expected_crc;
    integer fd, scan_result, test_count, line_number;
    integer read_result, token_index, char_index, char_code;
    string vector_file, line, message_token, crc_token, extra_token;
    ucie_crc16_candidate dut (.message(message), .crc(crc));

    // Exactly sized hexadecimal tokens; reject X/Z, partial and oversized values.
    function automatic bit valid_hex(input string token, input integer width);
        integer k, c;
        begin
            valid_hex = (token.len() == width);
            for (k = 0; k < token.len(); k = k + 1) begin
                c = token.getc(k);
                if (!((c >= 48 && c <= 57) ||
                      (c >= 65 && c <= 70) || (c >= 97 && c <= 102)))
                    valid_hex = 0;
            end
        end
    endfunction

    initial begin
        message = '0;
        expected_crc = '0;
        test_count = 0;
        line_number = 0;
        vector_file = "crc_random_vectors.txt";
        if ($value$plusargs("VECTOR_FILE=%s", vector_file)) begin end
        fd = $fopen(vector_file, "r");
        if (fd == 0) $fatal(1, "Cannot open vector file: %s", vector_file);

        // At most 1000 records plus one EOF probe. Every iteration either
        // consumes one line or terminates; malformed input cannot spin.
        for (line_number = 1; line_number <= 1001;
             line_number = line_number + 1) begin
            line = "";
            read_result = $fgets(line, fd);
            if (read_result == 0) begin
                if (!$feof(fd)) $fatal(1, "Vector read error at line %0d", line_number);
                break;
            end
            if (line_number > 1000)
                $fatal(1, "Extra vector record at line %0d", line_number);

            message_token = "";
            crc_token = "";
            extra_token = "";
            scan_result = $sscanf(line, "%s %s %s",
                                  message_token, crc_token, extra_token);
            if (scan_result != 2 ||
                !valid_hex(message_token, 256) || !valid_hex(crc_token, 4))
                $fatal(1, "Malformed vector record at line %0d", line_number);

            scan_result = $sscanf(line, "%h %h", message, expected_crc);
            if (scan_result != 2 || $isunknown({message, expected_crc}))
                $fatal(1, "Invalid vector values at line %0d", line_number);

            #1;
            if (crc !== expected_crc)
                $fatal(1, "CRC mismatch vector=%0d expected=%04h actual=%04h",
                       line_number, expected_crc, crc);
            test_count = test_count + 1;
        end
        $fclose(fd);
        if (test_count != 1000)
            $fatal(1, "Expected 1000 vectors, read %0d", test_count);
        $display("PASS: %0d randomized CRC vectors matched.", test_count);
        $display("REGRESSION_PASS: tb_crc_randomized_independent");
        $finish;
    end
    initial begin
        #10000;
        $fatal(1, "FAIL: randomized independent CRC watchdog");
    end
endmodule
