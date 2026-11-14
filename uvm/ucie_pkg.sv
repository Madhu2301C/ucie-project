// ============================================================================
// UCIe UVM Package
// ============================================================================
// Top-level package that includes all common transaction items and base tests.
// This package is imported by tb_top and all UVM components.
// ============================================================================

package ucie_pkg;

    // Import UVM library
    import uvm_pkg::*;

    // Include UVM macros
    `include "uvm_macros.svh"

    // Common transaction
    `include "ucie_transaction_item.sv"

    // Coverage component
    `include "env/ucie_coverage.sv"

    // Retry agent components
    `include "ucie_retry_driver.sv"
    `include "ucie_retry_monitor.sv"
    `include "ucie_retry_agent.sv"

    // Link agent components
    `include "ucie_link_sequencer.sv"
    `include "ucie_link_driver.sv"
    `include "ucie_link_monitor.sv"
    `include "ucie_link_agent.sv"

    // Environment
    `include "ucie_scoreboard.sv"
    `include "ucie_env.sv"

    // Sequences
    // Retry sequences
    `include "ucie_normal_tx_ack_sequence.sv"
    `include "ucie_nak_replay_sequence.sv"
    `include "ucie_timeout_replay_sequence.sv"
    `include "ucie_ack_nak_priority_sequence.sv"
    `include "ucie_multiple_nak_sequence.sv"
    `include "ucie_replay_backpressure_sequence.sv"

    // Link sequences
    `include "ucie_link_normal_sequence.sv"
    `include "ucie_link_error_sequence.sv"

    // Tests
    `include "ucie_base_test.sv"

endpackage
