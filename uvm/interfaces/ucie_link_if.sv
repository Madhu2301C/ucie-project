`ifndef UCIE_LINK_IF_SV
`define UCIE_LINK_IF_SV

// ============================================================================
// UCIe Link Interface
// ============================================================================
// Virtual interface for connecting the UCIe link controller DUT to UVM agents.
// Provides separate modports for driver and monitor.
// ============================================================================

interface ucie_link_if(input logic clk);

    logic rst_n;

    // DUT inputs
    logic send_req;
    logic [511:0] payload;
    logic [7:0]   sequence_num;
    logic inject_error;
    logic tx_ready;

    // DUT outputs
    logic tx_valid;
    logic busy;
    logic done;
    logic crc_error_seen;
    logic retransmit;
    logic [31:0] retransmission_count;
    logic [511:0] received_payload;

    // Driver modport
    modport DRIVER (
        input  clk,
        input  rst_n,
        output send_req,
        output payload,
        output sequence_num,
        output inject_error,
        output tx_ready,

        input  tx_valid,
        input  busy,
        input  done,
        input  crc_error_seen,
        input  retransmit,
        input  retransmission_count,
        input  received_payload
    );

    // Monitor modport
    modport MONITOR (
        input clk,
        input rst_n,
        input send_req,
        input payload,
        input sequence_num,
        input inject_error,
        input tx_ready,
        input tx_valid,
        input busy,
        input done,
        input crc_error_seen,
        input retransmit,
        input retransmission_count,
        input received_payload
    );

endinterface

`endif
