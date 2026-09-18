`default_nettype wire

module SL_MMF_MixingFilter
    import USG_parameter_pkg::*, USG_types::*;
(
    input  logic                                              clk,
    input  logic                                              rst_n,
    input  logic                                              frame_start,

    input  logic                                              valid_in,

    input  logic signed [N_CH_HF-1:0][MMF_DATA_WIDTH-1:0]     din,

    output logic                                              valid_out,
    output logic                                              chip_done_out,
    input  logic                                              ready_in,
    output logic [N_CH_HF-1:0][MMFX_OUT_W-1:0]                dout_i,
    output logic [N_CH_HF-1:0][MMFX_OUT_W-1:0]                dout_q
);

    logic lo_i [0:N_CH_HF-1];
    logic lo_q [0:N_CH_HF-1];
    logic signed [MMF_DATA_WIDTH-1:0] mix_i [0:N_CH_HF-1];
    logic signed [MMF_DATA_WIDTH-1:0] mix_q [0:N_CH_HF-1];

    logic sample_accepted;

    genvar gc;
    generate
        for (gc = 0; gc < N_CH_HF; gc++) begin : lo_mix
            SL_LO_Gen_60k u_lo (
                .clk         (clk),
                .rst_n       (rst_n),
                .frame_start (frame_start),
                .advance (sample_accepted),
                .lo_i    (lo_i[gc]),
                .lo_q    (lo_q[gc])
            );

            wire signed [BM_DATA_WIDTH-1:0] din_ext_gc;
            wire signed [BM_DATA_WIDTH-1:0] mix_full_i_gc, mix_full_q_gc;
            assign din_ext_gc =
                {{(BM_DATA_WIDTH-MMF_DATA_WIDTH){din[gc][MMF_DATA_WIDTH-1]}},
                 din[gc]};

            SL_BPSK_Mixer u_mix_i (
                .din  (din_ext_gc),
                .lo   (lo_i[gc]),
                .dout (mix_full_i_gc)
            );
            SL_BPSK_Mixer u_mix_q (
                .din  (din_ext_gc),
                .lo   (lo_q[gc]),
                .dout (mix_full_q_gc)
            );

            assign mix_i[gc] = mix_full_i_gc[MMF_DATA_WIDTH-1:0];
            assign mix_q[gc] = mix_full_q_gc[MMF_DATA_WIDTH-1:0];
        end
    endgenerate

    logic [MMFX_SAMP_CNT_W-1:0] samp_cnt;
    logic                  chip_boundary;

    assign chip_boundary = (samp_cnt == MMFX_SAMP_CNT_W'(MMFX_SAMP_PER_CHIP - 1));

    logic signed [MMFX_OUT_W-1:0] acc_i [0:N_CH_HF-1];
    logic signed [MMFX_OUT_W-1:0] acc_q [0:N_CH_HF-1];

    logic [N_CH_HF-1:0][MMFX_OUT_W-1:0] dout_i_r;
    logic [N_CH_HF-1:0][MMFX_OUT_W-1:0] dout_q_r;
    logic                       valid_out_r;

    assign valid_out     = valid_out_r;
    assign chip_done_out = valid_out_r;
    assign dout_i        = dout_i_r;
    assign dout_q        = dout_q_r;

    assign sample_accepted = valid_in & ~(valid_out_r & ~ready_in);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            samp_cnt    <= '0;
            valid_out_r <= 1'b0;
            for (int ch = 0; ch < N_CH_HF; ch++) begin
                acc_i[ch]    <= '0;
                acc_q[ch]    <= '0;
                dout_i_r[ch] <= '0;
                dout_q_r[ch] <= '0;
            end
        end else if (frame_start) begin
            samp_cnt    <= '0;
            valid_out_r <= 1'b0;
            for (int ch = 0; ch < N_CH_HF; ch++) begin
                acc_i[ch]    <= '0;
                acc_q[ch]    <= '0;
                dout_i_r[ch] <= '0;
                dout_q_r[ch] <= '0;
            end
        end else begin

            if (ready_in && valid_out_r)
                valid_out_r <= 1'b0;

            if (sample_accepted) begin
                if (chip_boundary) begin

                    for (int ch = 0; ch < N_CH_HF; ch++) begin
                        dout_i_r[ch] <= acc_i[ch] + MMFX_OUT_W'(mix_i[ch]);
                        dout_q_r[ch] <= acc_q[ch] + MMFX_OUT_W'(mix_q[ch]);

                        acc_i[ch] <= '0;
                        acc_q[ch] <= '0;
                    end
                    valid_out_r <= 1'b1;
                    samp_cnt    <= '0;
                end else begin

                    for (int ch = 0; ch < N_CH_HF; ch++) begin
                        acc_i[ch] <= acc_i[ch] + MMFX_OUT_W'(mix_i[ch]);
                        acc_q[ch] <= acc_q[ch] + MMFX_OUT_W'(mix_q[ch]);
                    end
                    samp_cnt <= samp_cnt + MMFX_SAMP_CNT_W'(1);
                end
            end
        end
    end

endmodule

module SL_LO_Gen_60k
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
        25'b1100001111000011110000111;

    localparam logic [LO_PERIOD-1:0] LO_Q_TABLE =
        25'b0000111100001111000011111;

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
