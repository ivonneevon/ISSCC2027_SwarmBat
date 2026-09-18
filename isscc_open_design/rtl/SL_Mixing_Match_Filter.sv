`default_nettype wire

module SL_Mixing_Match_Filter
    import USG_parameter_pkg::*, USG_types::*;
(
    input  logic                                              clk,
    input  logic                                              rst_n,
    input  logic                                              frame_start,
    input  logic                                              mode_HF_en,

    input  logic [CORR_N_CHIPS-1:0]                           coef,

    input  logic                                              valid_in,
    input  logic [N_CH_LF-1:0][MMF_DATA_WIDTH-1:0]            din_lf,
    input  logic [N_CH_HF-1:0][MMF_DATA_WIDTH-1:0]            din_hf,

    output logic                                              valid_out_lf,
    output logic                                              chip_done_out_lf,
    input  logic                                              ready_in_lf,
    output logic [N_CH_LF-1:0][MMF_DATA_WIDTH+11:0]           dout_lf_i,
    output logic [N_CH_LF-1:0][MMF_DATA_WIDTH+11:0]           dout_lf_q,

    output logic                                              valid_out_hf,
    output logic                                              chip_done_out_hf,
    input  logic                                              ready_in_hf,
    output logic [N_CH_HF-1:0][MMF_DATA_WIDTH+11:0]           dout_hf_i,
    output logic [N_CH_HF-1:0][MMF_DATA_WIDTH+11:0]           dout_hf_q
);

    SL_MMF_MatchedFilter u_matched_filter (
        .clk           (clk),
        .rst_n         (rst_n),
        .frame_start   (frame_start),
        .coef          (coef),
        .valid_in      (valid_in & ~mode_HF_en),
        .din           (din_lf),
        .valid_out     (valid_out_lf),
        .chip_done_out (chip_done_out_lf),
        .ready_in      (ready_in_lf),
        .dout_i        (dout_lf_i),
        .dout_q        (dout_lf_q)
    );

    SL_MMF_MixingFilter u_mixing_filter (
        .clk           (clk),
        .rst_n         (rst_n),
        .frame_start   (frame_start),
        .valid_in      (valid_in & mode_HF_en),
        .din           (din_hf),
        .valid_out     (valid_out_hf),
        .chip_done_out (chip_done_out_hf),
        .ready_in      (ready_in_hf),
        .dout_i        (dout_hf_i),
        .dout_q        (dout_hf_q)
    );

endmodule

`default_nettype wire
