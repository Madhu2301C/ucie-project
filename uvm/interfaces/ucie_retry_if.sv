// ============================================================================
// UCIe Retry Interface
// ============================================================================
// Virtual interface for connecting the retry controller DUT to UVM agents.
// Provides modport DUT for the design under test.
// ============================================================================

interface ucie_retry_if(input logic clk);

    // Inputs to DUT
    logic rst_n;
    logic send_req;
    logic [543:0] tx_flit;
    logic tx_ready;
    logic ack;
    logic nak;

    // Outputs from DUT
    logic tx_valid;
    logic [543:0] tx_flit_out;
    logic busy;
    logic retransmit;
    logic timeout_pulse;

    // DUT connection directions
    modport DUT (
        input  clk,
        input  rst_n,
        input  send_req,
        input  tx_flit,
        input  tx_ready,
        input  ack,
        input  nak,

        output tx_valid,
        output tx_flit_out,
        output busy,
        output retransmit,
        output timeout_pulse
    );

endinterface
