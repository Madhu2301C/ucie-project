
module ucie_link_top (
    input  logic         clk,
    input  logic         rst_n,
    input  logic         send_req,
    input  logic [511:0] payload,
    input  logic [7:0]   sequence_num,
    input  logic         inject_error,
    input  logic         tx_ready,

    output logic         tx_valid,
    output logic         busy,
    output logic         done,
    output logic         crc_error_seen,
    output logic         retransmit,
    output logic [31:0]  retransmission_count,
    output logic [511:0] received_payload
);

    logic [543:0] generated_flit;
    logic [543:0] retry_flit;
    logic [543:0] link_flit;

    logic [7:0] header_byte0, header_byte1;
    logic [511:0] rx_payload;
    logic [15:0] calculated_crc, received_crc;
    logic rx_crc_error, rx_flit_valid;

    logic ack_reg, nak_reg;
    logic injected_once;
    logic timeout_pulse;

    // 1. Build the 68-byte flit.
    ucie68b_flit_tx u_tx (
        .stack_id       (1'b0),
        .ack_nak_type   (2'b00),
        .sequence_num   (sequence_num),
        .payload        (payload),
        .flit_out       (generated_flit)
    );

    // 2. Retry controller holds the original flit.
    ucie_retry_controller #(
        .FLIT_WIDTH     (544),
        .TIMEOUT_CYCLES (10)
    ) u_retry (
        .clk            (clk),
        .rst_n          (rst_n),
        .send_req       (send_req),
        .tx_flit        (generated_flit),
        .tx_ready       (tx_ready),
        .ack            (ack_reg),
        .nak            (nak_reg),
        .tx_valid       (tx_valid),
        .tx_flit_out    (retry_flit),
        .busy           (busy),
        .retransmit     (retransmit),
        .timeout_pulse  (timeout_pulse)
    );

    // 3. Inject one error on the first accepted transmission.
    always_comb begin
        link_flit = retry_flit;

        if (inject_error && !injected_once &&
            tx_valid && tx_ready)
            link_flit[100] = ~retry_flit[100];
    end

    // 4. Receive and check the flit.
    ucie68b_flit_rx u_rx (
        .flit_in        (link_flit),
        .header_byte0   (header_byte0),
        .header_byte1   (header_byte1),
        .payload_out    (rx_payload),
        .calculated_crc (calculated_crc),
        .received_crc   (received_crc),
        .crc_error      (rx_crc_error),
        .flit_valid     (rx_flit_valid)
    );

    // 5. Register feedback so the retry controller sees
    // ACK/NAK in its WAIT_ACK state on the next cycle.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ack_reg              <= 1'b0;
            nak_reg              <= 1'b0;
            injected_once        <= 1'b0;
            done                 <= 1'b0;
            crc_error_seen       <= 1'b0;
            retransmission_count <= 32'd0;
            received_payload     <= '0;
        end
        else begin
            ack_reg <= 1'b0;
            nak_reg <= 1'b0;

            // Start of a new transaction
            if (send_req && !busy) begin
                done           <= 1'b0;
                injected_once  <= 1'b0;
                crc_error_seen <= 1'b0;
                received_payload <= '0;
            end

            if (tx_valid && tx_ready) begin

                // Mark error injection as completed
                if (inject_error && !injected_once)
                    injected_once <= 1'b1;

                // CRC error: send NAK
                if (rx_crc_error) begin
                    nak_reg        <= 1'b1;
                    crc_error_seen <= 1'b1;
                end

                // Valid flit: send ACK
                else if (rx_flit_valid) begin
                    ack_reg          <= 1'b1;
                    done             <= 1'b1;
                    received_payload <= rx_payload;
                end

                // Count accepted replay transmissions
                if (retransmit)
                    retransmission_count <=
                        retransmission_count + 1'b1;
            end
        end
    end

endmodule
