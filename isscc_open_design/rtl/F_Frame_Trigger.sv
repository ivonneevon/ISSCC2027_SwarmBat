`default_nettype wire

module F_Frame_Trigger
    import USG_parameter_pkg::*;
(
    input  logic                            clk,
    input  logic                            rst_n,

    input  logic [FRAME_DIVIDER_W-1:0]      CLK_DIVIDER,
    input  logic [FRAME_LENGTH_W-1:0]       FRAME_LENGTH,

    input  logic                            ON,

    input  logic                            mode_dir,
    input  logic                            mode_HF_en_ext,

    output reg                              frame_start,
    output reg                              mode_HF_en
);

    logic [FRAME_DIVIDER_W-1:0] div_cnt;
    logic                        tick;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            div_cnt <= '0;
            tick    <= 1'b0;
        end else if (div_cnt == CLK_DIVIDER - {{(FRAME_DIVIDER_W-1){1'b0}}, 1'b1}) begin
            div_cnt <= '0;
            tick    <= 1'b1;
        end else begin
            div_cnt <= div_cnt + {{(FRAME_DIVIDER_W-1){1'b0}}, 1'b1};
            tick    <= 1'b0;
        end
    end

    logic [FRAME_LENGTH_W-1:0] frame_cnt;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            frame_cnt   <= '0;
            frame_start <= 1'b0;
            mode_HF_en  <= 1'b0;
        end
        else if (tick
              && (frame_cnt == FRAME_LENGTH
                              - {{(FRAME_LENGTH_W-1){1'b0}}, 1'b1})
              && ON) begin

            frame_cnt   <= '0;
            frame_start <= 1'b1;
            mode_HF_en  <= mode_dir ? mode_HF_en_ext : ~mode_HF_en;
        end
        else if (tick
              && (frame_cnt == FRAME_LENGTH
                              - {{(FRAME_LENGTH_W-1){1'b0}}, 1'b1})) begin

            frame_cnt   <= '0;
            frame_start <= 1'b0;
        end
        else if (tick) begin
            frame_cnt   <= frame_cnt + {{(FRAME_LENGTH_W-1){1'b0}}, 1'b1};
            frame_start <= 1'b0;
        end
        else begin
            frame_start <= 1'b0;
        end
    end

endmodule

`default_nettype wire
