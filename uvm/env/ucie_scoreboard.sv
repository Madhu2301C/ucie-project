`ifndef UCIE_SCOREBOARD_SV
`define UCIE_SCOREBOARD_SV

`uvm_analysis_imp_decl(_retry)
`uvm_analysis_imp_decl(_link)

// Functional coverage covergroup - defined outside class
covergroup retry_cg with function sample(
    bit initial_tx_evt,
    bit replay_evt,
    bit ack_evt,
    bit nak_evt,
    bit timeout_evt,
    bit backpressure_evt,
    bit simultaneous_evt,
    int unsigned replay_depth
);

    cp_initial_tx: coverpoint initial_tx_evt {
        bins observed = {1};
        ignore_bins not_observed = {0};
    }

    cp_replay: coverpoint replay_evt {
        bins observed = {1};
        ignore_bins not_observed = {0};
    }

    cp_ack: coverpoint ack_evt {
        bins observed = {1};
        ignore_bins not_observed = {0};
    }

    cp_nak: coverpoint nak_evt {
        bins observed = {1};
        ignore_bins not_observed = {0};
    }

    cp_timeout: coverpoint timeout_evt {
        bins observed = {1};
        ignore_bins not_observed = {0};
    }

    cp_backpressure: coverpoint backpressure_evt {
        bins observed = {1};
        ignore_bins not_observed = {0};
    }

    cp_simultaneous: coverpoint simultaneous_evt {
        bins observed = {1};
        ignore_bins not_observed = {0};
    }

    cp_replay_depth: coverpoint replay_depth {
        bins no_replay = {0};
        bins single_replay = {1};
        bins multiple_replays = {[2:10]};
    }

endgroup

class ucie_scoreboard extends uvm_scoreboard;

    `uvm_component_utils(ucie_scoreboard)

    uvm_analysis_imp_retry #(ucie_transaction_item, ucie_scoreboard)
        retry_analysis_export;

    uvm_analysis_imp_link #(ucie_transaction_item, ucie_scoreboard)
        link_analysis_export;

    // Event counters
    int unsigned tx_handshake_count;
    int unsigned initial_tx_count;
    int unsigned replay_count;
    int unsigned ack_count;
    int unsigned nak_count;
    int unsigned timeout_count;
    int unsigned backpressure_count;
    int unsigned simultaneous_ack_nak_count;

    // Link transaction tracking
    int unsigned link_tx_count;
    int unsigned link_replay_count;
    int unsigned link_crc_error_count;
    int unsigned link_completion_count;

    // Link payload tracking
    logic [511:0] expected_payload;
    logic [7:0] expected_sequence_num;

    // Link transaction state
    bit link_transaction_started;
    bit link_payload_match;

    // Link event tracking
    bit link_prev_crc_error_seen;
    bit link_prev_done;

    // Snapshot of cumulative DUT replay counter
    logic [31:0] link_start_retransmission_count;

    // Sequence-number comparison result
    bit link_sequence_match;

    // Backpressure stability tracking
    bit stall_active;
    logic [543:0] stalled_flit;

    // Outstanding flit tracking
    bit outstanding_flit_valid;
    logic [543:0] original_flit;

    // Test case configuration
    string test_case;

    // Functional coverage handle
    retry_cg retry_coverage;

    function new(string name = "ucie_scoreboard",
                 uvm_component parent = null);

        super.new(name, parent);

        retry_analysis_export = new("retry_analysis_export", this);
        link_analysis_export  = new("link_analysis_export", this);

        tx_handshake_count = 0;
        initial_tx_count = 0;
        replay_count = 0;
        ack_count = 0;
        nak_count = 0;
        timeout_count = 0;
        backpressure_count = 0;
        simultaneous_ack_nak_count = 0;

        // Link transaction tracking initialization
        link_tx_count = 0;
        link_replay_count = 0;
        link_crc_error_count = 0;
        link_completion_count = 0;

        // Link payload tracking initialization
        expected_payload = '0;
        expected_sequence_num = '0;

        // Link transaction state initialization
        link_transaction_started = 0;
        link_prev_crc_error_seen = 1'b0;
        link_prev_done = 1'b0;
        link_start_retransmission_count = '0;
        link_sequence_match = 1'b0;
        link_payload_match = 1'b0;

        // Backpressure stability tracking initialization
        stall_active = 0;
        stalled_flit = '0;

        // Outstanding flit tracking initialization
        outstanding_flit_valid = 0;
        original_flit = '0;

        retry_coverage = new();

    endfunction


    function void build_phase(uvm_phase phase);

        super.build_phase(phase);

        if (!uvm_config_db #(string)::get(
                this, "", "test_case", test_case
            )) begin

            `uvm_fatal("SCOREBOARD",
                       "Test case configuration not received")

        end

        `uvm_info("SCOREBOARD",
                  $sformatf("Scoreboard configured for %s", test_case),
                  UVM_LOW)

    endfunction


    // ------------------------------------------------
    // Retry monitor -> Retry scoreboard
    // ------------------------------------------------
    function void write_retry(ucie_transaction_item t);

        bit initial_tx_evt;
        bit replay_evt;
        bit ack_evt;
        bit nak_evt;
        bit timeout_evt;
        bit backpressure_evt;
        bit simultaneous_evt;

        initial_tx_evt = 0;
        replay_evt = 0;
        ack_evt = 0;
        nak_evt = 0;
        timeout_evt = 0;
        backpressure_evt = 0;
        simultaneous_evt = 0;

        // ------------------------------------------------
        // 1. ACK observation
        // ------------------------------------------------
        if (t.ack === 1'b1) begin

            ack_count++;
            ack_evt = 1;

            `uvm_info("SCOREBOARD",
                      "ACK response observed",
                      UVM_MEDIUM)

            if (!outstanding_flit_valid) begin
                `uvm_error("SCOREBOARD",
                           "ACK received without an outstanding flit")
            end

        end

        // ------------------------------------------------
        // 2. NAK observation
        // ------------------------------------------------
        if (t.nak === 1'b1) begin

            nak_count++;
            nak_evt = 1;

            `uvm_info("SCOREBOARD",
                      "NAK response observed",
                      UVM_MEDIUM)

            if (!outstanding_flit_valid) begin
                `uvm_error("SCOREBOARD",
                           "NAK received without an outstanding flit")
            end

        end

        // ------------------------------------------------
        // 3. Simultaneous ACK and NAK
        // ------------------------------------------------
        if ((t.ack === 1'b1) &&
            (t.nak === 1'b1)) begin

            simultaneous_ack_nak_count++;
            simultaneous_evt = 1;

            `uvm_info("SCOREBOARD",
                      "Simultaneous ACK and NAK observed; ACK has priority",
                      UVM_MEDIUM)

        end

        // ------------------------------------------------
        // 4. Timeout observation
        // ------------------------------------------------
        if (t.timeout_pulse === 1'b1) begin

            timeout_count++;
            timeout_evt = 1;

            `uvm_info("SCOREBOARD",
                      "Timeout event observed",
                      UVM_MEDIUM)

            if (!outstanding_flit_valid) begin
                `uvm_error("SCOREBOARD",
                           "Timeout occurred without an outstanding flit")
            end

        end

        // ------------------------------------------------
        // 5. Transmission and backpressure checking
        // ------------------------------------------------
        if (t.tx_valid === 1'b1) begin

            // Check flit stability after a stall
            if (stall_active &&
                (t.tx_flit_out !== stalled_flit)) begin

                `uvm_error("SCOREBOARD",
                           "Flit changed during backpressure or at release")

            end

            // Transmission is stalled
            if (t.tx_ready === 1'b0) begin

                backpressure_count++;
                backpressure_evt = 1;

                stalled_flit = t.tx_flit_out;
                stall_active = 1'b1;

            end

            // Successful handshake
            else if (t.tx_ready === 1'b1) begin

                tx_handshake_count++;

                // First handshake: save original flit
                if (!outstanding_flit_valid) begin

                    initial_tx_count++;
                    initial_tx_evt = 1;

                    original_flit = t.tx_flit_out;
                    outstanding_flit_valid = 1'b1;

                    `uvm_info("SCOREBOARD",
                              "Initial transmission accepted; original flit saved",
                              UVM_MEDIUM)

                end

                // Subsequent handshake: verify replay
                else begin

                    replay_count++;
                    replay_evt = 1;

                    if (t.tx_flit_out !== original_flit) begin

                        `uvm_error("SCOREBOARD",
                                   "Replay flit does not match original transmitted flit")

                    end
                    else begin

                        `uvm_info("SCOREBOARD",
                                  "Replay accepted; original flit matched",
                                  UVM_MEDIUM)

                    end

                end

                stall_active = 0;

            end

        end

        // ------------------------------------------------
        // 6. ACK completes the outstanding transaction
        // ------------------------------------------------
        // ACK has priority over NAK in the DUT.
        // NAK and timeout retain the outstanding flit.
        if (t.ack === 1'b1) begin

            outstanding_flit_valid = 0;

        end

        // Sample functional coverage
        retry_coverage.sample(
            initial_tx_evt,
            replay_evt,
            ack_evt,
            nak_evt,
            timeout_evt,
            backpressure_evt,
            simultaneous_evt,
            replay_count
        );

    endfunction


    // ------------------------------------------------
    // Link monitor -> Link scoreboard
    // ------------------------------------------------
    function void write_link(ucie_transaction_item t);

        // ------------------------------------------------
        // 1. Count actual accepted transmissions
        // ------------------------------------------------
        // The monitor preserves pre-edge tx_valid and tx_ready values
        // when publishing a handshake event.
        if ((t.tx_valid === 1'b1) &&
            (t.tx_ready === 1'b1)) begin

            link_tx_count++;

            `uvm_info("SCOREBOARD",
                      "Link transmission handshake observed",
                      UVM_MEDIUM)

            // Capture expected transaction information once.
            if (!link_transaction_started) begin

                link_transaction_started = 1'b1;
                expected_payload = t.payload;
                expected_sequence_num = t.sequence_num;
                link_start_retransmission_count =
                    t.retransmission_count;

                `uvm_info("SCOREBOARD",
                          "Initial link transmission accepted",
                          UVM_MEDIUM)

            end

        end

        // ------------------------------------------------
        // 2. Detect CRC error only once
        // ------------------------------------------------
        if ((t.crc_error_seen === 1'b1) &&
            !link_prev_crc_error_seen) begin

            if (t.inject_error === 1'b1) begin

                link_crc_error_count++;

                `uvm_info("SCOREBOARD",
                          "CRC error detected with error injection",
                          UVM_MEDIUM)

            end

        end

        link_prev_crc_error_seen = t.crc_error_seen;

        // ------------------------------------------------
        // 3. Detect transaction completion
        // ------------------------------------------------
        if ((t.done === 1'b1) && !link_prev_done) begin

            link_completion_count++;

            `uvm_info("SCOREBOARD",
                      "Link transaction completion observed",
                      UVM_MEDIUM)

            if (t.received_payload === expected_payload) begin

                link_payload_match = 1'b1;

                `uvm_info("SCOREBOARD",
                          "PASS: Payload matches expected value",
                          UVM_MEDIUM)

            end
            else begin

                link_payload_match = 1'b0;

                `uvm_error("SCOREBOARD",
                           $sformatf(
                               "Payload mismatch: expected=%h received=%h",
                               expected_payload,
                               t.received_payload))

            end

            if (t.sequence_num === expected_sequence_num) begin

                link_sequence_match = 1'b1;

                `uvm_info("SCOREBOARD",
                          "PASS: Sequence number matches",
                          UVM_MEDIUM)

            end
            else begin

                link_sequence_match = 1'b0;

                `uvm_error("SCOREBOARD",
                           $sformatf(
                               "Sequence mismatch: expected=%0d received=%0d",
                               expected_sequence_num,
                               t.sequence_num))

            end

            if (t.retransmission_count >=
                link_start_retransmission_count) begin

                link_replay_count =
                    t.retransmission_count -
                    link_start_retransmission_count;

            end
            else begin

                `uvm_error("SCOREBOARD",
                           "Retransmission counter decreased unexpectedly")

            end

            `uvm_info("SCOREBOARD",
                      $sformatf(
                          "Replay count for transaction = %0d",
                          link_replay_count),
                      UVM_MEDIUM)

        end

        link_prev_done = t.done;

    endfunction


    function void report_phase(uvm_phase phase);

        int exp_initial_tx;
        int exp_replay;
        int exp_ack;
        int exp_nak;
        int exp_timeout;
        int exp_backpressure;
        int exp_simultaneous;

        super.report_phase(phase);

        `uvm_info("SCOREBOARD",
                  "========== RETRY SCOREBOARD SUMMARY ==========",
                  UVM_LOW)

        `uvm_info("SCOREBOARD",
                  $sformatf(
                      "Initial TX=%0d Total handshakes=%0d Replays=%0d",
                      initial_tx_count,
                      tx_handshake_count,
                      replay_count),
                  UVM_LOW)

        `uvm_info("SCOREBOARD",
                  $sformatf(
                      "ACK=%0d NAK=%0d Timeout=%0d",
                      ack_count,
                      nak_count,
                      timeout_count),
                  UVM_LOW)

        `uvm_info("SCOREBOARD",
                  $sformatf(
                      "Backpressure cycles=%0d Simultaneous ACK/NAK=%0d",
                      backpressure_count,
                      simultaneous_ack_nak_count),
                  UVM_LOW)

        // Expected-count checking for retry tests
        case (test_case)

            "TC01": begin
                exp_initial_tx = 1;
                exp_replay = 0;
                exp_ack = 1;
                exp_nak = 0;
                exp_timeout = 0;
                exp_backpressure = 0;
                exp_simultaneous = 0;
            end

            "TC02": begin
                exp_initial_tx = 1;
                exp_replay = 1;
                exp_ack = 1;
                exp_nak = 1;
                exp_timeout = 0;
                exp_backpressure = 0;
                exp_simultaneous = 0;
            end

            "TC03": begin
                exp_initial_tx = 1;
                exp_replay = 1;
                exp_ack = 1;
                exp_nak = 0;
                exp_timeout = 1;
                exp_backpressure = 0;
                exp_simultaneous = 0;
            end

            "TC04": begin
                exp_initial_tx = 1;
                exp_replay = 0;
                exp_ack = 1;
                exp_nak = 1;
                exp_timeout = 0;
                exp_backpressure = 0;
                exp_simultaneous = 1;
            end

            "TC05": begin
                exp_initial_tx = 1;
                exp_replay = 2;
                exp_ack = 1;
                exp_nak = 2;
                exp_timeout = 0;
                exp_backpressure = 0;
                exp_simultaneous = 0;
            end

            "TC06": begin
                exp_initial_tx = 1;
                exp_replay = 1;
                exp_ack = 1;
                exp_nak = 1;
                exp_timeout = 0;
                exp_backpressure = 5;
                exp_simultaneous = 0;
            end

        endcase

        // Link test case checking
        case (test_case)

            "LINK_NORMAL": begin
                `uvm_info("SCOREBOARD",
                      "Checking LINK_NORMAL test case",
                      UVM_MEDIUM)

                // Verify initial transmission observed
                if (link_tx_count >= 1) begin
                    `uvm_info("SCOREBOARD",
                          "PASS: Initial transmission observed",
                          UVM_MEDIUM)
                end
                else begin
                    `uvm_error("SCOREBOARD",
                          "FAIL: No initial transmission observed")
                end

                // Verify payload match
                if (link_payload_match) begin
                    `uvm_info("SCOREBOARD",
                          "PASS: Payload matches expected value",
                          UVM_MEDIUM)
                end
                else begin
                    `uvm_error("SCOREBOARD",
                          "FAIL: Payload mismatch")
                end

                // Verify transaction completed
                if (link_completion_count > 0) begin
                    `uvm_info("SCOREBOARD",
                          "PASS: Transaction completed successfully",
                          UVM_MEDIUM)
                end
                else begin
                    `uvm_error("SCOREBOARD",
                          "FAIL: Transaction did not complete")
                end

                // Verify no CRC error occurred.
                if (link_crc_error_count == 0) begin
                    `uvm_info("SCOREBOARD",
                              "PASS: No CRC errors in normal transmission",
                              UVM_MEDIUM)
                end
                else begin
                    `uvm_error("SCOREBOARD",
                               "FAIL: Unexpected CRC error in normal transmission")
                end

                // Verify no replay occurred.
                if (link_replay_count == 0) begin
                    `uvm_info("SCOREBOARD",
                              "PASS: No replay in normal transmission",
                              UVM_MEDIUM)
                end
                else begin
                    `uvm_error("SCOREBOARD",
                               "FAIL: Unexpected replay in normal transmission")
                end

                // Verify sequence number.
                if (link_sequence_match) begin
                    `uvm_info("SCOREBOARD",
                              "PASS: Sequence number matches",
                              UVM_MEDIUM)
                end
                else begin
                    `uvm_error("SCOREBOARD",
                               "FAIL: Sequence number mismatch")
                end
            end

            "LINK_ERROR": begin
                `uvm_info("SCOREBOARD",
                      "Checking LINK_ERROR test case",
                      UVM_MEDIUM)

                // Verify CRC error detected when error injection enabled
                if (link_crc_error_count > 0) begin
                    `uvm_info("SCOREBOARD",
                          "PASS: CRC error detected with error injection",
                          UVM_MEDIUM)
                end
                else begin
                    `uvm_error("SCOREBOARD",
                          "FAIL: CRC error not detected")
                end

                // Verify replay occurred
                if (link_replay_count > 0) begin
                    `uvm_info("SCOREBOARD",
                          "PASS: Replay observed",
                          UVM_MEDIUM)
                end
                else begin
                    `uvm_error("SCOREBOARD",
                          "FAIL: Replay not observed")
                end

                // Verify transaction completed
                if (link_completion_count > 0) begin
                    `uvm_info("SCOREBOARD",
                          "PASS: Transaction completed after error",
                          UVM_MEDIUM)
                end
                else begin
                    `uvm_error("SCOREBOARD",
                          "FAIL: Transaction did not complete after error")
                end

                // Verify final payload after replay.
                if (link_payload_match) begin
                    `uvm_info("SCOREBOARD",
                              "PASS: Payload recovered successfully after replay",
                              UVM_MEDIUM)
                end
                else begin
                    `uvm_error("SCOREBOARD",
                               "FAIL: Payload mismatch after replay")
                end

                // Verify sequence number after replay.
                if (link_sequence_match) begin
                    `uvm_info("SCOREBOARD",
                              "PASS: Sequence number matches after replay",
                              UVM_MEDIUM)
                end
                else begin
                    `uvm_error("SCOREBOARD",
                               "FAIL: Sequence number mismatch after replay")
                end
            end

            default: begin
                // Retry scenarios are checked by the expected-count table.
            end

        endcase

        // Compare actual and expected values for retry tests only.
        if (test_case inside {
                "TC01", "TC02", "TC03",
                "TC04", "TC05", "TC06"
            }) begin

            if ((initial_tx_count != exp_initial_tx) ||
                (replay_count != exp_replay) ||
                (ack_count != exp_ack) ||
                (nak_count != exp_nak) ||
                (timeout_count != exp_timeout) ||
                (backpressure_count != exp_backpressure) ||
                (simultaneous_ack_nak_count != exp_simultaneous)) begin

                `uvm_error("SCOREBOARD",
                           $sformatf(
                               "TEST %s FAILED: Expected counts do not match",
                               test_case))

            end
            else begin

                `uvm_info("SCOREBOARD",
                          $sformatf(
                              "TEST %s PASSED: All expected counts matched",
                              test_case),
                          UVM_LOW)

            end
        end

        if (outstanding_flit_valid) begin

            `uvm_error("SCOREBOARD",
                       "Test ended with an outstanding unacknowledged flit")

        end

        if (stall_active) begin

            `uvm_error("SCOREBOARD",
                       "Test ended while transmission was stalled")

        end

        `uvm_info("SCOREBOARD",
                  "===============================================",
                  UVM_LOW)

        `uvm_info("COVERAGE",
                  "========== FUNCTIONAL COVERAGE ==========",
                  UVM_LOW)

        `uvm_info("COVERAGE",
                  $sformatf("Retry functional coverage = %0.2f%%",
                            retry_coverage.get_inst_coverage()),
                  UVM_LOW)

        `uvm_info("COVERAGE",
                  "=========================================",
                  UVM_LOW)

    endfunction

endclass

`endif