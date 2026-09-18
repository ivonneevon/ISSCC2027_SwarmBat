`default_nettype wire

module SL_Phase_Rotator_LUT
    import USG_parameter_pkg::*, USG_types::*;
(
    input  logic                              clk,
    input  logic                              rst_n,
    input  logic                              frame_start,

    input  logic signed [PR_DATA_W-1:0]       din_i,
    input  logic signed [PR_DATA_W-1:0]       din_q,
    input  logic        [PR_ANGLE_W-1:0]      angle,

    input  logic                              valid_in,
    output logic                              ready_out,

    output logic signed [PR_DATA_W+1:0]       dout_i,
    output logic signed [PR_DATA_W+1:0]       dout_q,
    output logic                              valid_out,
    input  logic                              ready_in
);

    localparam logic signed [5:0] SIN_LUT [0:63] = '{
        6'sd 0, 6'sd 1, 6'sd 2, 6'sd 2, 6'sd 3, 6'sd 4, 6'sd 5, 6'sd 6,
        6'sd 6, 6'sd 7, 6'sd 8, 6'sd 9, 6'sd 9, 6'sd10, 6'sd11, 6'sd12,
        6'sd12, 6'sd13, 6'sd14, 6'sd15, 6'sd15, 6'sd16, 6'sd17, 6'sd17,
        6'sd18, 6'sd19, 6'sd19, 6'sd20, 6'sd20, 6'sd21, 6'sd22, 6'sd22,
        6'sd23, 6'sd23, 6'sd24, 6'sd24, 6'sd25, 6'sd25, 6'sd26, 6'sd26,
        6'sd27, 6'sd27, 6'sd28, 6'sd28, 6'sd28, 6'sd29, 6'sd29, 6'sd29,
        6'sd30, 6'sd30, 6'sd30, 6'sd31, 6'sd31, 6'sd31, 6'sd31, 6'sd31,
        6'sd31, 6'sd31, 6'sd31, 6'sd31, 6'sd31, 6'sd31, 6'sd31, 6'sd31
    };

    assign ready_out = 1'b1;

    logic [1:0]         quad_c;
    logic [5:0]         idx_fwd_c, idx_rev_c;
    logic signed [5:0]  lut_fwd_c, lut_rev_c;
    logic signed [5:0]  sin_v_c, cos_v_c;

    assign quad_c    = angle[15:14];
    assign idx_fwd_c = angle[13:8];
    assign idx_rev_c = 6'd63 - idx_fwd_c;
    assign lut_fwd_c = SIN_LUT[idx_fwd_c];
    assign lut_rev_c = SIN_LUT[idx_rev_c];

    always_comb begin
        unique case (quad_c)
            2'd0: begin sin_v_c =  lut_fwd_c; cos_v_c =  lut_rev_c; end
            2'd1: begin sin_v_c =  lut_rev_c; cos_v_c = -lut_fwd_c; end
            2'd2: begin sin_v_c = -lut_fwd_c; cos_v_c = -lut_rev_c; end
            2'd3: begin sin_v_c = -lut_rev_c; cos_v_c =  lut_fwd_c; end
        endcase
    end

    logic signed [PR_DATA_W-1:0] s1_din_i, s1_din_q;
    logic signed [5:0]           s1_sin,   s1_cos;
    logic                        s1_valid;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s1_din_i <= '0; s1_din_q <= '0;
            s1_sin   <= '0; s1_cos   <= '0;
            s1_valid <= 1'b0;
        end else if (frame_start) begin
            s1_din_i <= '0; s1_din_q <= '0;
            s1_sin   <= '0; s1_cos   <= '0;
            s1_valid <= 1'b0;
        end else begin
            s1_din_i <= din_i;
            s1_din_q <= din_q;
            s1_sin   <= sin_v_c;
            s1_cos   <= cos_v_c;
            s1_valid <= valid_in;
        end
    end

    localparam int PR_TRIM_W = PR_DATA_W - 4;

    logic signed [PR_TRIM_W-1:0]     din_i_trim, din_q_trim;
    logic signed [PR_TRIM_W+5:0]     mul_ic, mul_qs, mul_is, mul_qc;
    logic signed [PR_TRIM_W+6:0]     sum_i_c, sum_q_c;
    logic signed [PR_TRIM_W+6:0]     sum_i_shf, sum_q_shf;
    logic signed [PR_DATA_W+1:0]     s2_dout_i, s2_dout_q;
    logic                            s2_valid;

    always_comb begin

        din_i_trim = s1_din_i[PR_DATA_W-1:4];
        din_q_trim = s1_din_q[PR_DATA_W-1:4];

        mul_ic = din_i_trim * s1_cos;
        mul_qs = din_q_trim * s1_sin;
        mul_is = din_i_trim * s1_sin;
        mul_qc = din_q_trim * s1_cos;

        sum_i_c   = $signed({mul_ic[PR_TRIM_W+5], mul_ic}) - $signed({mul_qs[PR_TRIM_W+5], mul_qs});
        sum_q_c   = $signed({mul_is[PR_TRIM_W+5], mul_is}) + $signed({mul_qc[PR_TRIM_W+5], mul_qc});
        sum_i_shf = sum_i_c >>> 1;
        sum_q_shf = sum_q_c >>> 1;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s2_dout_i <= '0; s2_dout_q <= '0; s2_valid <= 1'b0;
        end else if (frame_start) begin
            s2_dout_i <= '0; s2_dout_q <= '0; s2_valid <= 1'b0;
        end else begin
            s2_dout_i <= sum_i_shf[PR_DATA_W+1:0];
            s2_dout_q <= sum_q_shf[PR_DATA_W+1:0];
            s2_valid  <= s1_valid;
        end
    end

    assign dout_i    = s2_dout_i;
    assign dout_q    = s2_dout_q;
    assign valid_out = s2_valid;

endmodule

`default_nettype wire
