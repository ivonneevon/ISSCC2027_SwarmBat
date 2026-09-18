module SL_Beamformer
    import USG_parameter_pkg::*, USG_types::*;
(
    input  logic                                             clk,
    input  logic                                             rst_n,

    input  logic [12:0]                                      phase_inc,

    input  logic                                             frame_start,

    input  logic signed [N_CH-1:0][MF_DATA_W-1:0]     mf_data_i,
    input  logic signed [N_CH-1:0][MF_DATA_W-1:0]     mf_data_q,
    input  logic                                             mf_valid,
    input  logic                                             mf_chip_done,

    input  logic [N_CH-1:0][TOF_FULL_W-1:0]           dg_tofs,
    input  logic                                             dg_valid,
    input  logic [POSITION_WIDTH-1:0]                        dg_pos,
    output logic                                             dg_ready,

    output logic [ENV_OUT_W-1:0]                             voxel_intensity,
    output logic signed [ADDER_OUT_W-1:0]                    voxel_sum_i,
    output logic signed [ADDER_OUT_W-1:0]                    voxel_sum_q,
    output logic [POSITION_WIDTH-1:0]                        voxel_pos,
    output logic                                             voxel_valid
);

    logic signed [N_CH-1:0][MF_DATA_W-1:0]  da_data_i, da_data_q;
    logic [N_CH-1:0][ANGLE_W-1:0]           da_angles;
    logic                                          da_valid;
    logic [POSITION_WIDTH-1:0]                     da_pos;

    logic [N_CH-1:0] cordic_ready;
    wire all_cordic_idle;
    assign all_cordic_idle = &cordic_ready;

    SL_Delay_Application_IQ u_delay_app (
        .clk         (clk),
        .rst_n       (rst_n),
        .phase_inc   (phase_inc),
        .frame_start (frame_start),

        .mf_data_i   (mf_data_i),
        .mf_data_q   (mf_data_q),
        .mf_valid    (mf_valid),
        .mf_chip_done(mf_chip_done),

        .up_DG_tofs  (dg_tofs),
        .up_DG_valid (dg_valid),
        .up_DG_pos   (dg_pos),
        .up_DG_ready (dg_ready),

        .down_ready  (all_cordic_idle),

        .down_data_i (da_data_i),
        .down_data_q (da_data_q),
        .down_angles (da_angles),
        .down_valid  (da_valid),
        .down_pos    (da_pos)
    );

    logic signed [N_CH-1:0][CORDIC_OUT_W-1:0] cordic_out_i, cordic_out_q;
    logic [N_CH-1:0]                          cordic_valid;

    logic all_cordic_valid;
    assign all_cordic_valid = &cordic_valid;

    genvar ch;
    generate
        for (ch = 0; ch < N_CH; ch++) begin : gen_cordic

            SL_Phase_Rotator_LUT u_cordic (
                .clk         (clk),
                .rst_n       (rst_n),
                .frame_start (frame_start),
                .din_i       (da_data_i[ch]),
                .din_q       (da_data_q[ch]),
                .angle       (da_angles[ch]),
                .valid_in    (da_valid),
                .ready_out   (cordic_ready[ch]),
                .dout_i      (cordic_out_i[ch]),
                .dout_q      (cordic_out_q[ch]),
                .valid_out   (cordic_valid[ch]),
                .ready_in    (all_cordic_valid)
            );

        end
    endgenerate

    localparam int LUT_POS_PIPE_DEPTH = 2;
    logic [POSITION_WIDTH-1:0] pos_pipe [0:LUT_POS_PIPE_DEPTH-1];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int p = 0; p < LUT_POS_PIPE_DEPTH; p++)
                pos_pipe[p] <= '0;
        end else if (frame_start) begin
            for (int p = 0; p < LUT_POS_PIPE_DEPTH; p++)
                pos_pipe[p] <= '0;
        end else begin
            pos_pipe[0] <= da_pos;
            for (int p = 1; p < LUT_POS_PIPE_DEPTH; p++)
                pos_pipe[p] <= pos_pipe[p-1];
        end
    end

    logic adder_up_valid;
    assign adder_up_valid = all_cordic_valid;

    SL_Sum_Up u_adder (
        .clk            (clk),
        .rst_n          (rst_n),
        .frame_start    (frame_start),
        .up_data_i      (cordic_out_i),
        .up_data_q      (cordic_out_q),
        .up_voxel_pos   (pos_pipe[LUT_POS_PIPE_DEPTH-1]),
        .up_valid       (adder_up_valid),
        .down_intensity (voxel_intensity),
        .down_sum_i     (voxel_sum_i),
        .down_sum_q     (voxel_sum_q),
        .down_voxel_pos (voxel_pos),
        .down_valid     (voxel_valid),
        .down_ready     (1'b1)
    );

endmodule
