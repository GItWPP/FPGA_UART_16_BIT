module uart_tx_16bit
#(
    parameter CLK_FREQ  = 50_000_000,
    parameter BAUD_RATE = 115200
)
(
    input               clk,
    input               rst_n,
    input               tx_dv,
    input      [7:0]    tx_byte,
    output reg          tx_ready,
    output reg          txd
);

    localparam integer CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;
    localparam integer BAUD_CNT_MAX = CLKS_PER_BIT - 1;

    localparam [1:0] S_IDLE  = 2'd0;
    localparam [1:0] S_START = 2'd1;
    localparam [1:0] S_DATA  = 2'd2;
    localparam [1:0] S_STOP  = 2'd3;

    reg [1:0]  state;
    reg [31:0] baud_cnt;
    reg [2:0]  bit_cnt;
    reg [7:0]  data_buf;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= S_IDLE;
            baud_cnt <= 32'd0;
            bit_cnt  <= 3'd0;
            data_buf <= 8'd0;
            tx_ready <= 1'b1;
            txd      <= 1'b1;
        end
        else begin
            case (state)
                S_IDLE: begin
                    tx_ready <= 1'b1;
                    txd      <= 1'b1;
                    baud_cnt <= 32'd0;
                    bit_cnt  <= 3'd0;

                    if (tx_dv) begin
                        tx_ready <= 1'b0;
                        data_buf <= tx_byte;
                        state    <= S_START;
                    end
                end

                S_START: begin
                    txd <= 1'b0;
                    if (baud_cnt == BAUD_CNT_MAX) begin
                        baud_cnt <= 32'd0;
                        state    <= S_DATA;
                    end
                    else begin
                        baud_cnt <= baud_cnt + 1'b1;
                    end
                end

                S_DATA: begin
                    txd <= data_buf[bit_cnt];
                    if (baud_cnt == BAUD_CNT_MAX) begin
                        baud_cnt <= 32'd0;
                        if (bit_cnt == 3'd7) begin
                            bit_cnt <= 3'd0;
                            state   <= S_STOP;
                        end
                        else begin
                            bit_cnt <= bit_cnt + 1'b1;
                        end
                    end
                    else begin
                        baud_cnt <= baud_cnt + 1'b1;
                    end
                end

                S_STOP: begin
                    txd <= 1'b1;
                    if (baud_cnt == BAUD_CNT_MAX) begin
                        baud_cnt <= 32'd0;
                        state    <= S_IDLE;
                    end
                    else begin
                        baud_cnt <= baud_cnt + 1'b1;
                    end
                end

                default: begin
                    state <= S_IDLE;
                end
            endcase
        end
    end

endmodule
