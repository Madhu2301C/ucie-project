
module ucie_retry_controller #(
    parameter int FLIT_WIDTH = 544,
    parameter int TIMEOUT_CYCLES = 10
) (
    input  logic                  clk,
    input  logic                  rst_n,

    input  logic                  send_req,
    input  logic [FLIT_WIDTH-1:0] tx_flit,

    input  logic                  tx_ready,
    input  logic                  ack,
    input  logic                  nak,

    output logic                  tx_valid,
    output logic [FLIT_WIDTH-1:0] tx_flit_out,
    output logic                  busy,
    output logic                  retransmit,
    output logic                  timeout_pulse
);

    // ------------------------------------------------
    // Timeout configuration
    // ------------------------------------------------

    localparam int TIMEOUT_LIMIT =
        (TIMEOUT_CYCLES < 1) ? 1 : TIMEOUT_CYCLES;

    localparam int COUNT_WIDTH =
        (TIMEOUT_LIMIT > 1) ?
        $clog2(TIMEOUT_LIMIT + 1) : 1;

    // ------------------------------------------------
    // FSM state definition
    // ------------------------------------------------

    typedef enum logic [1:0] {
        IDLE,
        SEND_NEW,
        WAIT_ACK,
        SEND_REPLAY
    } state_t;

    state_t state;

    // ------------------------------------------------
    // Internal registers
    // ------------------------------------------------

    logic [FLIT_WIDTH-1:0] retry_buffer;

    logic [COUNT_WIDTH-1:0] timeout_count;

    // ------------------------------------------------
    // Combinational output logic
    // ------------------------------------------------

    always_comb begin

        tx_valid      = 1'b0;
        tx_flit_out   = '0;
        busy          = (state != IDLE);
        retransmit    = 1'b0;
        timeout_pulse = 1'b0;

        case (state)

            // ----------------------------------------
            // Send original flit
            // ----------------------------------------

            SEND_NEW: begin

                tx_valid    = 1'b1;
                tx_flit_out = retry_buffer;

            end

            // ----------------------------------------
            // Wait for ACK, NAK, or timeout
            // ----------------------------------------

            WAIT_ACK: begin

                if ((timeout_count >= TIMEOUT_LIMIT) &&
                    !ack && !nak) begin

                    timeout_pulse = 1'b1;

                end

            end

            // ----------------------------------------
            // Replay previously stored flit
            // ----------------------------------------

            SEND_REPLAY: begin

                tx_valid    = 1'b1;
                tx_flit_out = retry_buffer;

                // Assert retransmit only when replay
                // transmission is accepted
                retransmit  = tx_ready;

            end

            default: begin

                // IDLE: no transmission

            end

        endcase

    end

    // ------------------------------------------------
    // Sequential FSM logic
    // ------------------------------------------------

    always_ff @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            state         <= IDLE;
            retry_buffer  <= '0;
            timeout_count <= '0;

        end
        else begin

            case (state)

                // ------------------------------------
                // IDLE
                // ------------------------------------

                IDLE: begin

                    timeout_count <= '0;

                    if (send_req) begin

                        // Store original flit
                        retry_buffer <= tx_flit;

                        state <= SEND_NEW;

                    end

                end

                // ------------------------------------
                // SEND_NEW
                // ------------------------------------

                SEND_NEW: begin

                    if (tx_valid && tx_ready) begin

                        timeout_count <= '0;

                        state <= WAIT_ACK;

                    end

                end

                // ------------------------------------
                // WAIT_ACK
                // ------------------------------------

                WAIT_ACK: begin

                    // ACK has highest priority
                    if (ack) begin

                        timeout_count <= '0;

                        state <= IDLE;

                    end

                    // NAK triggers retransmission
                    else if (nak) begin

                        timeout_count <= '0;

                        state <= SEND_REPLAY;

                    end

                    // Timeout triggers retransmission
                    else if (timeout_pulse) begin

                        timeout_count <= '0;

                        state <= SEND_REPLAY;

                    end

                    // Continue waiting
                    else begin

                        timeout_count <= timeout_count + 1'b1;

                    end

                end

                // ------------------------------------
                // SEND_REPLAY
                // ------------------------------------

                SEND_REPLAY: begin

                    if (tx_valid && tx_ready) begin

                        timeout_count <= '0;

                        state <= WAIT_ACK;

                    end

                end

                // ------------------------------------
                // Default recovery
                // ------------------------------------

                default: begin

                    state         <= IDLE;
                    timeout_count <= '0;

                end

            endcase

        end

    end

endmodule
