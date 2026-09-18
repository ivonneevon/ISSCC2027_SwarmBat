`default_nettype wire

module SL_MMF_MatchedFilter
    import USG_parameter_pkg::*, USG_types::*;
(
    input  logic                                              clk,
    input  logic                                              rst_n,
    input  logic                                              frame_start,

    input  logic [CORR_N_CHIPS-1:0]                           coef,

    input  logic                                              valid_in,

    input  logic signed [N_CH_LF-1:0][MMF_DATA_WIDTH-1:0]     din,

    output logic                                              valid_out,
    output logic                                              chip_done_out,
    input  logic                                              ready_in,
    output logic [N_CH_LF-1:0][MMFM_OUT_W-1:0]                dout_i,
    output logic [N_CH_LF-1:0][MMFM_OUT_W-1:0]                dout_q
);

    logic lo_i [0:N_CH_LF-1];
    logic lo_q [0:N_CH_LF-1];
    logic signed [MMF_DATA_WIDTH-1:0] mix_i [0:N_CH_LF-1];
    logic signed [MMF_DATA_WIDTH-1:0] mix_q [0:N_CH_LF-1];

    logic sample_accepted;

    genvar gc;
    generate
        for (gc = 0; gc < N_CH_LF; gc++) begin : lo_mix
            SL_LO_Gen u_lo (
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

    logic signed [MMF_DATA_WIDTH-1:0] mix_latch [0:MMFM_N_GROUPS-1][0:MMFM_N_BRANCHES-1];

    logic [MMFM_BR_W-1:0] branch_cnt;
    logic            corr_vin;

    logic            corr_vout    [0:MMFM_N_GROUPS-1];
    logic [MMFM_BR_W-1:0] corr_obr    [0:MMFM_N_GROUPS-1];
    logic signed [MMFM_OUT_W-1:0] corr_dout_w [0:MMFM_N_GROUPS-1];

    logic            corr_proc;
    logic            corr_busy    [0:MMFM_N_GROUPS-1];
    logic            corr_pending [0:MMFM_N_GROUPS-1];

    logic any_busy, any_pending;
    always_comb begin
        any_busy    = 1'b0;
        any_pending = 1'b0;
        for (int g = 0; g < MMFM_N_GROUPS; g++) begin
            any_busy    = any_busy    | corr_busy[g];
            any_pending = any_pending | corr_pending[g];
        end
    end

    generate
        for (gc = 0; gc < MMFM_N_GROUPS; gc++) begin : tdm
            SL_Correlator_TDM_SRAM u_corr (
                .clk             (clk),
                .rst_n           (rst_n),
                .frame_start     (frame_start),
                .coef            (coef),
                .branch_id       (branch_cnt),
                .valid_in        (corr_vin),
                .ready_out       (),
                .din             (mix_latch[gc][branch_cnt]),
                .process_pending (corr_proc),
                .chip_busy       (corr_busy[gc]),
                .has_pending     (corr_pending[gc]),
                .out_branch_id   (corr_obr[gc]),
                .valid_out       (corr_vout[gc]),
                .ready_in        (1'b1),
                .dout            (corr_dout_w[gc])
            );
        end
    endgenerate

    logic [MMFM_CH_PER_GROUP-1:0][MMFM_OUT_W-1:0] grp_out_i [0:MMFM_N_GROUPS-1];
    logic [MMFM_CH_PER_GROUP-1:0][MMFM_OUT_W-1:0] grp_out_q [0:MMFM_N_GROUPS-1];

    generate
        for (gc = 0; gc < MMFM_N_GROUPS; gc++) begin : cap
            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    for (int j = 0; j < MMFM_CH_PER_GROUP; j++) begin
                        grp_out_i[gc][j] <= '0;
                        grp_out_q[gc][j] <= '0;
                    end
                end else if (frame_start) begin
                    for (int j = 0; j < MMFM_CH_PER_GROUP; j++) begin
                        grp_out_i[gc][j] <= '0;
                        grp_out_q[gc][j] <= '0;
                    end
                end else if (corr_vout[gc]) begin
                    if (!corr_obr[gc][0])
                        grp_out_i[gc][corr_obr[gc] >> 1] <= corr_dout_w[gc];
                    else
                        grp_out_q[gc][corr_obr[gc] >> 1] <= corr_dout_w[gc];
                end
            end
        end
    endgenerate

    generate
        for (gc = 0; gc < MMFM_N_GROUPS; gc++) begin : out_assign
            genvar j;
            for (j = 0; j < MMFM_CH_PER_GROUP; j++) begin : ch_assign
                assign dout_i[gc * MMFM_CH_PER_GROUP + j] = grp_out_i[gc][j];
                assign dout_q[gc * MMFM_CH_PER_GROUP + j] = grp_out_q[gc][j];
            end
        end
    endgenerate

    typedef enum logic [1:0] {
        SCH_IDLE  = 2'd0,
        SCH_RUN   = 2'd1,
        SCH_DRAIN = 2'd2,
        SCH_CHIP  = 2'd3
    } sch_t;

    sch_t sch;
    logic valid_out_r;
    logic [1:0] drain_cnt;
    logic [1:0] chip_phase;
    logic got_output;

    assign corr_proc      = (sch == SCH_CHIP) && (chip_phase != 2'd3);

    logic any_corr_busy;
    always_comb begin
        any_corr_busy = 1'b0;
        for (int g = 0; g < MMFM_N_GROUPS; g++)
            any_corr_busy = any_corr_busy | corr_busy[g];
    end

    logic frame_armed;

    assign sample_accepted = valid_in & (sch == SCH_IDLE) & ~any_corr_busy & ~frame_armed;
    assign chip_done_out   = valid_out_r;
    assign valid_out       = valid_out_r;
    assign corr_vin        = (sch == SCH_RUN);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sch         <= SCH_IDLE;
            frame_armed <= 1'b1;
            branch_cnt  <= '0;
            drain_cnt   <= '0;
            chip_phase  <= '0;
            got_output  <= 1'b0;
            valid_out_r <= 1'b0;
            for (int gg = 0; gg < MMFM_N_GROUPS; gg++)
                for (int bb = 0; bb < MMFM_N_BRANCHES; bb++)
                    mix_latch[gg][bb] <= '0;
        end else if (frame_start) begin
            sch         <= SCH_IDLE;
            frame_armed <= 1'b1;
            branch_cnt  <= '0;
            drain_cnt   <= '0;
            chip_phase  <= '0;
            got_output  <= 1'b0;
            valid_out_r <= 1'b0;
            for (int gg = 0; gg < MMFM_N_GROUPS; gg++)
                for (int bb = 0; bb < MMFM_N_BRANCHES; bb++)
                    mix_latch[gg][bb] <= '0;
        end else begin
            if (ready_in && valid_out_r)
                valid_out_r <= 1'b0;

            if (frame_armed && valid_in && ~any_corr_busy)
                frame_armed <= 1'b0;

            if (sch == SCH_RUN || sch == SCH_DRAIN || sch == SCH_CHIP)
                for (int gg = 0; gg < MMFM_N_GROUPS; gg++)
                    if (corr_vout[gg])
                        got_output <= 1'b1;

            case (sch)
                SCH_IDLE: begin
                    if (sample_accepted) begin
                        for (int gg = 0; gg < MMFM_N_GROUPS; gg++)
                            for (int j = 0; j < MMFM_CH_PER_GROUP; j++) begin
                                mix_latch[gg][2*j]   <= mix_i[gg * MMFM_CH_PER_GROUP + j];
                                mix_latch[gg][2*j+1] <= mix_q[gg * MMFM_CH_PER_GROUP + j];
                            end
                        branch_cnt <= '0;
                        sch        <= SCH_RUN;
                    end
                end

                SCH_RUN: begin
                    if (branch_cnt == MMFM_BR_W'(MMFM_N_BRANCHES - 1)) begin
                        drain_cnt <= '0;
                        sch       <= SCH_DRAIN;
                    end else begin
                        branch_cnt <= branch_cnt + 1;
                    end
                end

                SCH_DRAIN: begin
                    if (drain_cnt == 2'd2) begin
                        if (any_pending) begin

                            chip_phase <= 2'd0;
                            sch        <= SCH_CHIP;
                        end else begin

                            if (got_output) begin
                                valid_out_r <= 1'b1;
                                got_output  <= 1'b0;
                            end
                            sch <= SCH_IDLE;
                        end
                    end else begin
                        drain_cnt <= drain_cnt + 1;
                    end
                end

                SCH_CHIP: begin

                    case (chip_phase)
                        2'd0: begin

                            chip_phase <= 2'd1;
                        end
                        2'd1: begin

                            if (any_busy)
                                chip_phase <= 2'd2;

                        end
                        2'd2: begin

                            if (!any_busy)
                                chip_phase <= 2'd3;
                        end
                        2'd3: begin

                            if (!any_pending && got_output) begin
                                valid_out_r <= 1'b1;
                                got_output  <= 1'b0;
                            end
                            sch <= SCH_IDLE;
                        end
                    endcase
                end

                default: sch <= SCH_IDLE;
            endcase
        end
    end

endmodule

`default_nettype wire
