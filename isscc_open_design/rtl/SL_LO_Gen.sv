`default_nettype wire

module SL_LO_Gen
    import USG_parameter_pkg::*, USG_types::*;
(
    input  logic clk,
    input  logic rst_n,
    input  logic frame_start,

    input  logic advance,

    output logic lo_i,
    output logic lo_q
);

    localparam logic [LO_PERIOD-1:0] LO_I_TABLE =
        25'b1110000001111110000001111;

    localparam logic [LO_PERIOD-1:0] LO_Q_TABLE =
        25'b0000001111110000001111111;

    logic [LO_CNT_W-1:0] phase_r;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            phase_r <= '0;
        end else if (frame_start) begin
            phase_r <= '0;
        end else if (advance) begin
            if (phase_r == LO_CNT_W'(LO_PERIOD - 1))
                phase_r <= '0;
            else
                phase_r <= phase_r + LO_CNT_W'(1);
        end
    end

    assign lo_i = LO_I_TABLE[phase_r];
    assign lo_q = LO_Q_TABLE[phase_r];

endmodule

`default_nettype wire
