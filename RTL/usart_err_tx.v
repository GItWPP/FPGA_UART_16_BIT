module ERROR_UART_TX #
(
    parameter CLK_FREQ  = 50_000_000,
    parameter BAUD_RATE = 115200
)
(
    input                       sys_clk,
    input                       sys_rst_n,
	
    input                       ERR_DATA_VAL,
    input      signed [15:0]    ERROR,
    input      signed [15:0]    ERROR1,
	
    output                      uart_txd,
    output reg                  tx_busy
);

    localparam [1:0] M_IDLE      = 2'd0;
    localparam [1:0] M_SEND_BYTE = 2'd1;
    localparam [1:0] M_WAIT_LOW  = 2'd2;
    localparam [1:0] M_WAIT_HIGH = 2'd3;

    reg [1:0]  state;
    reg [2:0]  byte_idx;

    reg        tx_dv;
    reg [7:0]  tx_byte;
    wire       tx_ready;

    reg [15:0] error_buf;
    reg [15:0] error1_buf;
    reg [15:0] pending_error;
    reg [15:0] pending_error1;
    reg        pending_valid;

    function [7:0] frame_byte_sel;
        input [2:0]  index;
        input [15:0] err_data;
        input [15:0] err1_data;
        begin
            case (index)
                3'd0: frame_byte_sel = 8'h55;
                3'd1: frame_byte_sel = err_data[15:8];
                3'd2: frame_byte_sel = err_data[7:0];
                3'd3: frame_byte_sel = err1_data[15:8];
                3'd4: frame_byte_sel = err1_data[7:0];
                default: frame_byte_sel = 8'h00;
            endcase
        end
    endfunction

    uart_tx_16bit #
    (
        .CLK_FREQ (CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    )
    u_uart_tx_16bit
    (
        .clk     (sys_clk),
        .rst_n   (sys_rst_n),
        .tx_dv   (tx_dv),
        .tx_byte (tx_byte),
        .tx_ready(tx_ready),
        .txd     (uart_txd)
    );

    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            state         <= M_IDLE;
            byte_idx      <= 3'd0;
            tx_dv         <= 1'b0;
            tx_byte       <= 8'd0;
            error_buf     <= 16'd0;
            error1_buf    <= 16'd0;
            pending_error <= 16'd0;
            pending_error1<= 16'd0;
            pending_valid <= 1'b0;
            tx_busy       <= 1'b0;
        end
        else begin
            tx_dv <= 1'b0;

            case (state)
                M_IDLE: begin
                    tx_busy <= 1'b0;

                    if (ERR_DATA_VAL) begin
                        error_buf <= ERROR;
                        error1_buf <= ERROR1;
                        byte_idx  <= 3'd0;
                        tx_busy   <= 1'b1;
                        state     <= M_SEND_BYTE;
                    end
                    else if (pending_valid) begin
                        error_buf     <= pending_error;
                        error1_buf    <= pending_error1;
                        pending_valid <= 1'b0;
                        byte_idx      <= 3'd0;
                        tx_busy       <= 1'b1;
                        state         <= M_SEND_BYTE;
                    end
                end

                M_SEND_BYTE: begin
                    tx_busy <= 1'b1;

                    if (ERR_DATA_VAL) begin
                        pending_error <= ERROR;
                        pending_error1 <= ERROR1;
                        pending_valid <= 1'b1;
                    end

                    if (tx_ready) begin
                        tx_byte <= frame_byte_sel(byte_idx, error_buf, error1_buf);
                        tx_dv   <= 1'b1;
                        state   <= M_WAIT_LOW;
                    end
                end

                M_WAIT_LOW: begin
                    tx_busy <= 1'b1;

                    if (ERR_DATA_VAL) begin
                        pending_error <= ERROR;
                        pending_error1 <= ERROR1;
                        pending_valid <= 1'b1;
                    end

                    if (!tx_ready) begin
                        state <= M_WAIT_HIGH;
                    end
                end

                M_WAIT_HIGH: begin
                    tx_busy <= 1'b1;

                    if (ERR_DATA_VAL) begin
                        pending_error <= ERROR;
                        pending_error1 <= ERROR1;
                        pending_valid <= 1'b1;
                    end

                    if (tx_ready) begin
                        if (byte_idx == 3'd4) begin
                            if (ERR_DATA_VAL) begin
                                error_buf     <= ERROR;
                                error1_buf    <= ERROR1;
                                pending_valid <= 1'b0;
                                byte_idx      <= 3'd0;
                                state         <= M_SEND_BYTE;
                            end
                            else if (pending_valid) begin
                                error_buf     <= pending_error;
                                error1_buf    <= pending_error1;
                                pending_valid <= 1'b0;
                                byte_idx      <= 3'd0;
                                state         <= M_SEND_BYTE;
                            end
                            else begin
                                tx_busy <= 1'b0;
                                state   <= M_IDLE;
                            end
                        end
                        else begin
                            byte_idx <= byte_idx + 1'b1;
                            state    <= M_SEND_BYTE;
                        end
                    end
                end

                default: begin
                    state <= M_IDLE;
                end
            endcase
        end
    end

endmodule
