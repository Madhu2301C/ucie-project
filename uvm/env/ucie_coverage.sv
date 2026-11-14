`ifndef UCIE_COVERAGE_SV
`define UCIE_COVERAGE_SV

// Separate analysis implementation names for the two monitor connections.
`uvm_analysis_imp_decl(_retry_cov)
`uvm_analysis_imp_decl(_link_cov)

class ucie_coverage extends uvm_component;

    `uvm_component_utils(ucie_coverage)

    // ------------------------------------------------------------
    // Analysis exports
    // ------------------------------------------------------------

    uvm_analysis_imp_retry_cov #(
        ucie_transaction_item,
        ucie_coverage
    ) retry_cov_export;

    uvm_analysis_imp_link_cov #(
        ucie_transaction_item,
        ucie_coverage
    ) link_cov_export;


    // ------------------------------------------------------------
    // Retry coverage tracking
    // ------------------------------------------------------------

    bit retry_tx_handshake_seen;
    int unsigned retry_replay_depth;

    bit retry_had_nak;
    bit retry_had_timeout;
    bit retry_had_backpressure;
    bit retry_had_simultaneous;


    // ------------------------------------------------------------
    // Link coverage tracking
    // ------------------------------------------------------------

    bit link_transaction_started;

    bit link_prev_crc_error;
    bit link_prev_done;

    bit link_had_crc_error;
    bit link_error_injected;

    logic [31:0] link_start_retransmission_count;

    int unsigned link_replay_depth;


    // ------------------------------------------------------------
    // Retry event coverage
    // ------------------------------------------------------------

    covergroup retry_event_cg with function sample(
        bit initial_tx_evt,
        bit replay_evt,
        bit ack_evt,
        bit nak_evt,
        bit timeout_evt,
        bit backpressure_evt,
        bit simultaneous_evt
    );

        option.per_instance = 1;

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

    endgroup


    // ------------------------------------------------------------
    // Retry transaction summary coverage
    // Sampled when an ACK completes a retry transaction.
    // ------------------------------------------------------------

    covergroup retry_summary_cg with function sample(
        bit had_nak,
        bit had_timeout,
        bit had_backpressure,
        bit had_simultaneous,
        int unsigned replay_depth
    );

        option.per_instance = 1;

        cp_nak: coverpoint had_nak {
            bins no_nak = {0};
            bins nak_seen = {1};
        }

        cp_timeout: coverpoint had_timeout {
            bins no_timeout = {0};
            bins timeout_seen = {1};
        }

        cp_backpressure: coverpoint had_backpressure {
            bins no_backpressure = {0};
            bins backpressure_seen = {1};
        }

        cp_simultaneous: coverpoint had_simultaneous {
            bins no_simultaneous = {0};
            bins simultaneous_seen = {1};
        }

        cp_replay_depth: coverpoint replay_depth {
            bins no_replay = {0};
            bins single_replay = {1};
            bins multiple_replays = {[2:10]};
            bins deep_replay = {[11:$]};
        }

    endgroup


    // ------------------------------------------------------------
    // Link event coverage
    // ------------------------------------------------------------

    covergroup link_event_cg with function sample(
        bit initial_handshake_evt,
        bit crc_error_evt,
        bit completion_evt
    );

        option.per_instance = 1;

        cp_initial_handshake: coverpoint initial_handshake_evt {
            bins observed = {1};
            ignore_bins not_observed = {0};
        }

        cp_crc_error: coverpoint crc_error_evt {
            bins observed = {1};
            ignore_bins not_observed = {0};
        }

        cp_completion: coverpoint completion_evt {
            bins observed = {1};
            ignore_bins not_observed = {0};
        }

    endgroup


    // ------------------------------------------------------------
    // Link transaction summary coverage
    // Sampled when the link transaction completes.
    // ------------------------------------------------------------

    covergroup link_summary_cg with function sample(
        bit injected_error,
        bit crc_error_seen,
        bit replay_seen,
        bit payload_match,
        int unsigned replay_depth
    );

        option.per_instance = 1;

        cp_injected_error: coverpoint injected_error {
            bins normal_transaction = {0};
            bins error_injected = {1};
        }

        cp_crc_error: coverpoint crc_error_seen {
            bins no_crc_error = {0};
            bins crc_error_detected = {1};
        }

        cp_replay: coverpoint replay_seen {
            bins no_replay = {0};
            bins replay_observed = {1};
        }

        cp_payload_match: coverpoint payload_match {
            bins payload_recovered = {1};
            ignore_bins payload_mismatch = {0};
        }

        // Cover only the two intended successful link scenarios.
        // Normal transaction:      injected_error=0, crc_error=0, replay=0, payload_match=1  -> 4'b0001
        // Error recovery success:  injected_error=1, crc_error=1, replay=1, payload_match=1  -> 4'b1111
        cp_valid_recovery_path: coverpoint {
            injected_error,
            crc_error_seen,
            replay_seen,
            payload_match
        } {
            bins normal_success          = {4'b0001};
            bins error_recovery_success  = {4'b1111};
        }

        cp_replay_depth: coverpoint replay_depth {
            bins no_replay = {0};
            bins single_replay = {1};
            bins multiple_replays = {[2:10]};
            bins deep_replay = {[11:$]};
        }

    endgroup


    // ------------------------------------------------------------
    // Constructor
    // ------------------------------------------------------------

    function new(string name = "ucie_coverage",
                 uvm_component parent = null);

        super.new(name, parent);

        retry_cov_export = new("retry_cov_export", this);
        link_cov_export  = new("link_cov_export", this);

        retry_event_cg   = new();
        retry_summary_cg = new();

        link_event_cg    = new();
        link_summary_cg  = new();

        retry_tx_handshake_seen = 0;
        retry_replay_depth      = 0;

        retry_had_nak           = 0;
        retry_had_timeout       = 0;
        retry_had_backpressure  = 0;
        retry_had_simultaneous  = 0;

        link_transaction_started = 0;

        link_prev_crc_error = 0;
        link_prev_done      = 0;

        link_had_crc_error   = 0;
        link_error_injected  = 0;

        link_start_retransmission_count = '0;
        link_replay_depth               = 0;

    endfunction


    // ------------------------------------------------------------
    // Retry monitor analysis callback
    // ------------------------------------------------------------

    function void write_retry_cov(ucie_transaction_item t);

        bit initial_tx_evt;
        bit replay_evt;

        bit ack_evt;
        bit nak_evt;
        bit timeout_evt;

        bit backpressure_evt;
        bit simultaneous_evt;

        initial_tx_evt   = 0;
        replay_evt       = 0;

        ack_evt          = (t.ack === 1'b1);
        nak_evt          = (t.nak === 1'b1);
        timeout_evt      = (t.timeout_pulse === 1'b1);

        backpressure_evt = (
            (t.tx_valid === 1'b1) &&
            (t.tx_ready === 1'b0)
        );

        simultaneous_evt = ack_evt && nak_evt;


        // --------------------------------------------------------
        // Detect accepted transmissions.
        // First accepted handshake = initial transmission.
        // Subsequent accepted handshakes = replay transmissions.
        // --------------------------------------------------------

        if ((t.tx_valid === 1'b1) &&
            (t.tx_ready === 1'b1)) begin

            if (!retry_tx_handshake_seen) begin

                initial_tx_evt = 1;
                retry_tx_handshake_seen = 1;

            end
            else begin

                replay_evt = 1;
                retry_replay_depth++;

            end

        end


        // --------------------------------------------------------
        // Remember transaction-level events.
        // --------------------------------------------------------

        if (nak_evt)
            retry_had_nak = 1;

        if (timeout_evt)
            retry_had_timeout = 1;

        if (backpressure_evt)
            retry_had_backpressure = 1;

        if (simultaneous_evt)
            retry_had_simultaneous = 1;


        // --------------------------------------------------------
        // Sample retry event coverage.
        // --------------------------------------------------------

        retry_event_cg.sample(
            initial_tx_evt,
            replay_evt,
            ack_evt,
            nak_evt,
            timeout_evt,
            backpressure_evt,
            simultaneous_evt
        );


        // --------------------------------------------------------
        // ACK marks the end of the current retry transaction.
        // Sample the accumulated transaction summary.
        // --------------------------------------------------------

        if (ack_evt) begin

            retry_summary_cg.sample(
                retry_had_nak,
                retry_had_timeout,
                retry_had_backpressure,
                retry_had_simultaneous,
                retry_replay_depth
            );

            // Prepare for another transaction if the test
            // sends more than one transaction.
            retry_tx_handshake_seen = 0;
            retry_replay_depth      = 0;

            retry_had_nak          = 0;
            retry_had_timeout      = 0;
            retry_had_backpressure = 0;
            retry_had_simultaneous = 0;

        end

    endfunction


    // ------------------------------------------------------------
    // Link monitor analysis callback
    // ------------------------------------------------------------

    function void write_link_cov(ucie_transaction_item t);

        bit initial_handshake_evt;
        bit crc_error_evt;
        bit completion_evt;

        bit payload_match;
        bit replay_seen;

        int unsigned transaction_replay_depth;

        initial_handshake_evt = 0;
        crc_error_evt         = 0;
        completion_evt        = 0;

        payload_match         = 0;
        replay_seen           = 0;

        transaction_replay_depth = 0;


        // --------------------------------------------------------
        // Detect the first accepted handshake of a transaction.
        // --------------------------------------------------------

        if ((t.tx_valid === 1'b1) &&
            (t.tx_ready === 1'b1) &&
            !link_transaction_started) begin

            initial_handshake_evt = 1;

            link_transaction_started = 1;

            link_error_injected = (t.inject_error === 1'b1);

            // Save the replay counter at transaction start.
            if (!$isunknown(t.retransmission_count)) begin
                link_start_retransmission_count =
                    t.retransmission_count;
            end
            else begin
                link_start_retransmission_count = '0;
            end

            link_had_crc_error = 0;
            link_replay_depth  = 0;

        end


        // --------------------------------------------------------
        // Detect CRC error rising edge.
        // --------------------------------------------------------

        if ((t.crc_error_seen === 1'b1) &&
            !link_prev_crc_error) begin

            crc_error_evt = 1;
            link_had_crc_error = 1;

        end

        link_prev_crc_error = (t.crc_error_seen === 1'b1);


        // --------------------------------------------------------
        // Detect transaction completion rising edge.
        // --------------------------------------------------------

        if ((t.done === 1'b1) && !link_prev_done) begin

            completion_evt = 1;

        end

        link_prev_done = (t.done === 1'b1);


        // --------------------------------------------------------
        // Sample link event coverage.
        // --------------------------------------------------------

        link_event_cg.sample(
            initial_handshake_evt,
            crc_error_evt,
            completion_evt
        );


        // --------------------------------------------------------
        // At completion, calculate replay depth and sample
        // transaction-level coverage.
        // --------------------------------------------------------

        if (completion_evt) begin

            if (link_transaction_started &&
                !$isunknown(t.retransmission_count) &&
                !$isunknown(link_start_retransmission_count) &&
                (t.retransmission_count >=
                 link_start_retransmission_count)) begin

                transaction_replay_depth =
                    t.retransmission_count -
                    link_start_retransmission_count;

            end
            else begin

                transaction_replay_depth = 0;

            end

            link_replay_depth = transaction_replay_depth;

            replay_seen = (transaction_replay_depth > 0);

            payload_match = (
                t.received_payload === t.payload
            );

            link_summary_cg.sample(
                link_error_injected,
                link_had_crc_error,
                replay_seen,
                payload_match,
                transaction_replay_depth
            );


            `uvm_info(
                "UCIE_LINK_COV",
                $sformatf(
                    "Link coverage sampled: injected_error=%0b CRC_error=%0b replay_depth=%0d payload_match=%0b",
                    link_error_injected,
                    link_had_crc_error,
                    transaction_replay_depth,
                    payload_match
                ),
                UVM_MEDIUM
            )


            // Reset transaction-level tracking.
            link_transaction_started = 0;

            link_had_crc_error  = 0;
            link_error_injected = 0;

            link_replay_depth = 0;

        end

    endfunction


    // ------------------------------------------------------------
    // Coverage report
    // ------------------------------------------------------------

    function void report_phase(uvm_phase phase);

        super.report_phase(phase);

        `uvm_info(
            "UCIE_COVERAGE",
            "==============================================",
            UVM_NONE
        )

        `uvm_info(
            "UCIE_COVERAGE",
            "        UCIE FUNCTIONAL COVERAGE REPORT",
            UVM_NONE
        )

        `uvm_info(
            "UCIE_COVERAGE",
            "==============================================",
            UVM_NONE
        )

        `uvm_info(
            "UCIE_COVERAGE",
            $sformatf(
                "Retry event coverage       : %0.2f%%",
                retry_event_cg.get_coverage()
            ),
            UVM_NONE
        )

        `uvm_info(
            "UCIE_COVERAGE",
            $sformatf(
                "Retry summary coverage     : %0.2f%%",
                retry_summary_cg.get_coverage()
            ),
            UVM_NONE
        )

        `uvm_info(
            "UCIE_COVERAGE",
            $sformatf(
                "Link event coverage        : %0.2f%%",
                link_event_cg.get_coverage()
            ),
            UVM_NONE
        )

        `uvm_info(
            "UCIE_COVERAGE",
            $sformatf(
                "Link summary coverage      : %0.2f%%",
                link_summary_cg.get_coverage()
            ),
            UVM_NONE
        )

        `uvm_info(
            "UCIE_COVERAGE",
            "==============================================",
            UVM_NONE
        )

    endfunction

endclass

`endif