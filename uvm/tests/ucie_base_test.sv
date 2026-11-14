`ifndef UCIE_BASE_TEST_SV
`define UCIE_BASE_TEST_SV

class ucie_base_test extends uvm_test;

    `uvm_component_utils(ucie_base_test)

    ucie_env env;

    string test_mode;
    string test_case;

    function new(string name = "ucie_base_test",
                 uvm_component parent = null);
        super.new(name, parent);
    endfunction


    function void build_phase(uvm_phase phase);

        super.build_phase(phase);

        // ------------------------------------------------
        // 1. Read verification mode
        // ------------------------------------------------
        if (!$value$plusargs("TEST_MODE=%s", test_mode))
            test_mode = "RETRY";

        // ------------------------------------------------
        // 2. Read test case based on mode
        // ------------------------------------------------
        if (!$value$plusargs("UCIE_TESTCASE=%s", test_case)) begin

            if (test_mode == "RETRY")
                test_case = "TC06";
            else if (test_mode == "LINK")
                test_case = "LINK_NORMAL";

        end

        // ------------------------------------------------
        // 3. Validate mode and test case
        // ------------------------------------------------
        if (test_mode == "RETRY") begin

            if (!(test_case inside {
                "TC01", "TC02", "TC03",
                "TC04", "TC05", "TC06"
            })) begin

                `uvm_fatal("UCIE_BASE_TEST",
                           $sformatf(
                               "Invalid RETRY test case: %s",
                               test_case
                           ))
            end

        end
        else if (test_mode == "LINK") begin

            if (!(test_case inside {
                "LINK_NORMAL",
                "LINK_ERROR"
            })) begin

                `uvm_fatal("UCIE_BASE_TEST",
                           $sformatf(
                               "Invalid LINK test case: %s",
                               test_case
                           ))
            end

        end
        else begin

            `uvm_fatal("UCIE_BASE_TEST",
                       $sformatf(
                           "Invalid TEST_MODE: %s",
                           test_mode
                       ))
        end

        // ------------------------------------------------
        // 4. Configure environment
        // ------------------------------------------------
        uvm_config_db #(string)::set(
            this,
            "env",
            "test_mode",
            test_mode
        );

        // ------------------------------------------------
        // 5. Configure unified scoreboard
        // ------------------------------------------------
        uvm_config_db #(string)::set(
            this,
            "env.scoreboard",
            "test_case",
            test_case
        );

        // ------------------------------------------------
        // 6. Create environment
        // ------------------------------------------------
        env = ucie_env::type_id::create(
            "env", this
        );

        `uvm_info("UCIE_BASE_TEST",
                  $sformatf(
                      "Selected mode=%s, test_case=%s",
                      test_mode, test_case
                  ),
                  UVM_LOW)

    endfunction


    task run_phase(uvm_phase phase);

        uvm_sequence #(ucie_transaction_item) seq;

        phase.raise_objection(this);

        // =================================================
        // RETRY TEST MODE
        // =================================================
        if (test_mode == "RETRY") begin

            case (test_case)

                "TC01":
                    seq = ucie_normal_tx_ack_sequence::type_id::create(
                        "tc01_seq"
                    );

                "TC02":
                    seq = ucie_nak_replay_sequence::type_id::create(
                        "tc02_seq"
                    );

                "TC03":
                    seq = ucie_timeout_replay_sequence::type_id::create(
                        "tc03_seq"
                    );

                "TC04":
                    seq = ucie_ack_nak_priority_sequence::type_id::create(
                        "tc04_seq"
                    );

                "TC05":
                    seq = ucie_multiple_nak_sequence::type_id::create(
                        "tc05_seq"
                    );

                "TC06":
                    seq = ucie_replay_backpressure_sequence::type_id::create(
                        "tc06_seq"
                    );

            endcase

            `uvm_info("UCIE_BASE_TEST",
                      $sformatf("Starting retry test: %s", test_case),
                      UVM_LOW)

            seq.start(env.retry_agent.ucie_retry_seqr);

            repeat (2)
                @(posedge env.retry_agent.monitor.vif.clk);

        end

        // =================================================
        // LINK TEST MODE
        // =================================================
        else if (test_mode == "LINK") begin

            case (test_case)

                "LINK_NORMAL":
                    seq = ucie_link_normal_sequence::type_id::create(
                        "link_normal_seq"
                    );

                "LINK_ERROR":
                    seq = ucie_link_error_sequence::type_id::create(
                        "link_error_seq"
                    );

            endcase

            `uvm_info("UCIE_BASE_TEST",
                      $sformatf("Starting link test: %s", test_case),
                      UVM_LOW)

            seq.start(env.link_agent.sequencer);

            repeat (2)
                @(posedge env.link_agent.monitor.vif.clk);

        end

        `uvm_info("UCIE_BASE_TEST",
                  $sformatf(
                      "Completed mode=%s test=%s",
                      test_mode, test_case
                  ),
                  UVM_LOW)

        phase.drop_objection(this);

    endtask

endclass

`endif
