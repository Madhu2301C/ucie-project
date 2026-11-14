`ifndef UCIE_ENV_SV
`define UCIE_ENV_SV

class ucie_env extends uvm_env;

    `uvm_component_utils(ucie_env)

    // Agents
    ucie_retry_agent retry_agent;
    ucie_link_agent  link_agent;

    // One unified scoreboard
    ucie_scoreboard scoreboard;

    // Coverage component
    ucie_coverage coverage;

    // Selected verification mode
    string test_mode;

    function new(string name = "ucie_env",
                 uvm_component parent = null);
        super.new(name, parent);
    endfunction


    function void build_phase(uvm_phase phase);

        super.build_phase(phase);

        // Read verification mode
        if (!uvm_config_db#(string)::get(
                this, "", "test_mode", test_mode)) begin

            test_mode = "RETRY";

            `uvm_warning("UCIE_ENV",
                         "TEST_MODE not configured. Defaulting to RETRY")

        end

        // Configure agent activity before creating agents
        if (test_mode == "RETRY") begin

            uvm_config_db#(uvm_active_passive_enum)::set(
                this, "retry_agent", "is_active", UVM_ACTIVE
            );

            uvm_config_db#(uvm_active_passive_enum)::set(
                this, "link_agent", "is_active", UVM_PASSIVE
            );

        end
        else if (test_mode == "LINK") begin

            uvm_config_db#(uvm_active_passive_enum)::set(
                this, "retry_agent", "is_active", UVM_PASSIVE
            );

            uvm_config_db#(uvm_active_passive_enum)::set(
                this, "link_agent", "is_active", UVM_ACTIVE
            );

        end
        else begin

            `uvm_fatal("UCIE_ENV",
                       $sformatf("Invalid TEST_MODE: %s", test_mode))

        end

        // Create agents
        retry_agent = ucie_retry_agent::type_id::create(
            "retry_agent", this
        );

        link_agent = ucie_link_agent::type_id::create(
            "link_agent", this
        );

        // Create one scoreboard
        scoreboard = ucie_scoreboard::type_id::create(
            "scoreboard", this
        );

        // Create coverage component
        coverage = ucie_coverage::type_id::create(
            "coverage", this
        );

        `uvm_info("UCIE_ENV",
                  $sformatf("Verification mode: %s", test_mode),
                  UVM_LOW)

    endfunction


    function void connect_phase(uvm_phase phase);

        super.connect_phase(phase);

        // Retry monitor -> Unified scoreboard
        retry_agent.monitor.analysis_port.connect(
            scoreboard.retry_analysis_export
        );

        // Link monitor -> Same unified scoreboard
        link_agent.monitor.analysis_port.connect(
            scoreboard.link_analysis_export
        );

        // Retry monitor -> Coverage component
        retry_agent.monitor.analysis_port.connect(
            coverage.retry_cov_export
        );

        // Link monitor -> Coverage component
        link_agent.monitor.analysis_port.connect(
            coverage.link_cov_export
        );

        `uvm_info("UCIE_ENV",
                  "Both monitors connected to unified scoreboard",
                  UVM_LOW)

    endfunction

endclass

`endif
