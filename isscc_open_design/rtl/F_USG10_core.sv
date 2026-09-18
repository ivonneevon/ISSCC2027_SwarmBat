module F_USG10_core
    import USG_parameter_pkg::*, USG_types::*;
(
    input  logic                                   clk,
    input  logic                                   rst_n,

    output logic                                   rst_n_LF,
    output logic                                   rst_n_HF,

    input  logic [N_CH_CFG/4-1:0]                  adc_lf_cmp_out,
    input  logic                                   adc_lf_ch1_index,
    input  logic [N_CH_CFG/4-1:0]                  adc_hf_cmp_out,
    input  logic                                   adc_hf_ch1_index,

    input  logic                                   mode_dir,
    input  logic                                   mode_HF_en_ext,

    input  logic                                   ON,

    input  logic                                   serial_en,
    input  logic                                   serial_in,
    output logic                                   serial_out,

    input  logic                                   adc_ext_dir,
    input  logic [31:0]                            adc_data_ext,
    input  logic                                   adc_valid_ext,
    output logic [31:0]                            adc_data_out,
    output logic                                   adc_valid,

    input  logic                                   pos_dir,
    input  logic [POSITION_WIDTH-1:0]              pos_data_ext,
    input  logic                                   pos_valid_ext,
    output logic                                   pos_ready,

    output logic [ENV_OUT_W-1:0]                   voxel_value,
    output logic [POSITION_WIDTH-1:0]              voxel_pos,
    output logic                                   voxel_valid,

    output logic                                   frame_start,

    output logic                                   SAMPL_EN_LF,
    output logic                                   DCOC_EN_LF,
    output logic                                   PGA_EN_LF,
    output logic                                   LPF_EN_LF,
    output logic                                   ADC_EN_LF,
    output logic                                   RX_SHUNT_LF,
    output logic                                   RX_ON_LF,
    output logic                                   TX_HZ_LF,
    output logic                                   TX_ON_LF,
    output logic                                   SAMPL_EN_HF,
    output logic                                   DCOC_EN_HF,
    output logic                                   PGA_EN_HF,
    output logic                                   LPF_EN_HF,
    output logic                                   ADC_EN_HF,
    output logic                                   RX_SHUNT_HF,
    output logic                                   RX_ON_HF,
    output logic                                   TX_HZ_HF,
    output logic                                   TX_ON_HF,

    output logic [7:0]                             CLK_SMPL_LF,
    output logic [7:0]                             CLK_SMPL_HF,
    output logic [7:0]                             CLK_CMP_LF,
    output logic [7:0]                             CLK_CMP_HF,

    output logic [31:0]                            out_A_LF,
    output logic [31:0]                            out_B_LF,
    output logic [31:0]                            out_A_HF,
    output logic [31:0]                            out_B_HF
);

    assign rst_n_LF = rst_n;
    assign rst_n_HF = rst_n;

    logic mode_HF_en;

    USG_Config_t USG_PARAM;
    logic        param_done;

    USG_parameter_manager u_param_manager (
        .clk        (clk),
        .rst_n      (rst_n),
        .serial_in  (serial_in),
        .serial_en  (serial_en),
        .serial_out (serial_out),
        .done       (param_done),
        .USG_PARAM  (USG_PARAM)
    );

    wire [PSG_R_START_W-1:0] r_start_active =
        mode_HF_en ? USG_PARAM.dg.DG_PSG_R_START_HF
                   : USG_PARAM.dg.DG_PSG_R_START_LF;

    logic [N_CH-1:0][RX_COORD_W-1:0] rx_words_internal;
    always_comb begin
        for (int c = 0; c < N_CH; c++) begin
            rx_words_internal[c] =
                USG_PARAM.dg.rx_coor[c*RX_COORD_W +: RX_COORD_W];
        end
    end

    JY_AFE_CTR #(
        .P_NUM_CHANNELS (32),
        .P_NUM_TRX      (8)
    ) u_afe_ctr (
        .clk          (clk),
        .rst_n        (rst_n),
        .frame_start  (frame_start),

        .mode_HF_en   (mode_HF_en),

        .Delay_RX_clk              (USG_PARAM.ac.Delay_RX_clk),
        .Delay_Sample_clk          (USG_PARAM.ac.Delay_Sample_clk),
        .Delay_TX_cycle_LF         (USG_PARAM.ac.Delay_TX_cycle_LF),
        .Delay_TX_cycle_HF         (USG_PARAM.ac.Delay_TX_cycle_HF),
        .Delay_Local_TX_clk        (USG_PARAM.ac.Delay_Local_TX_clk),
        .Delay_ADC_EN_clk          (USG_PARAM.adcc.Delay_ADC_EN_clk),
        .P_PULSE_clk_LF            (USG_PARAM.tpgt.P_PULSE_clk_LF),
        .P_MID_clk_LF              (USG_PARAM.tpgt.P_MID_clk_LF),
        .P_NUM_pulse_LF            (USG_PARAM.tpgt.P_NUM_pulse_LF),
        .P_PHASE_CODE_LF           (USG_PARAM.tpgt.P_PHASE_CODE_LF),
        .P_PHASE_CODE_UNIT_pulse_LF(USG_PARAM.tpgt.P_PHASE_CODE_UNIT_pulse_LF),
        .P_PULSE_clk_HF            (USG_PARAM.tpgt.P_PULSE_clk_HF),
        .P_MID_clk_HF              (USG_PARAM.tpgt.P_MID_clk_HF),
        .P_NUM_pulse_HF            (USG_PARAM.tpgt.P_NUM_pulse_HF),
        .P_PHASE_CODE_HF           (USG_PARAM.tpgt.P_PHASE_CODE_HF),
        .P_PHASE_CODE_UNIT_pulse_HF(USG_PARAM.tpgt.P_PHASE_CODE_UNIT_pulse_HF),
        .ch_delay_flat             (USG_PARAM.dgd.ch_delay_flat),

        .TRX_MODE_LF(),
        .SAMPL_EN_LF(SAMPL_EN_LF), .DCOC_EN_LF (DCOC_EN_LF),
        .PGA_EN_LF  (PGA_EN_LF),   .LPF_EN_LF  (LPF_EN_LF),
        .ADC_EN_LF  (ADC_EN_LF),   .RX_SHUNT_LF(RX_SHUNT_LF),
        .RX_ON_LF   (RX_ON_LF),    .TX_HZ_LF   (TX_HZ_LF),
        .TX_ON_LF   (TX_ON_LF),
        .TRX_MODE_HF(),
        .SAMPL_EN_HF(SAMPL_EN_HF), .DCOC_EN_HF (DCOC_EN_HF),
        .PGA_EN_HF  (PGA_EN_HF),   .LPF_EN_HF  (LPF_EN_HF),
        .ADC_EN_HF  (ADC_EN_HF),   .RX_SHUNT_HF(RX_SHUNT_HF),
        .RX_ON_HF   (RX_ON_HF),    .TX_HZ_HF   (TX_HZ_HF),
        .TX_ON_HF   (TX_ON_HF),

        .CLK_SMPL_LF(CLK_SMPL_LF), .CLK_SMPL_HF(CLK_SMPL_HF),
        .CLK_CMP_LF (CLK_CMP_LF),  .CLK_CMP_HF (CLK_CMP_HF),

        .out_A_LF(out_A_LF), .out_B_LF(out_B_LF),
        .out_A_HF(out_A_HF), .out_B_HF(out_B_HF)
    );

    logic                                  adcw_valid;
    logic [N_CH_ALL-1:0][ADC_WIDTH-1:0]    adcw_data;

    F_ADC_Wrapper u_adcw (
        .clk                (clk),
        .rst_n              (rst_n),
        .frame_start        (frame_start),
        .adc_lf_cmp_out     (adc_lf_cmp_out),
        .adc_lf_ch1_index   (adc_lf_ch1_index),
        .adc_hf_cmp_out     (adc_hf_cmp_out),
        .adc_hf_ch1_index   (adc_hf_ch1_index),

        .adc_ext_dir        (adc_ext_dir),
        .mode_HF_en         (mode_HF_en),
        .adc_data_32ch_ext  (adc_data_ext),
        .adc_valid_ext      (adc_valid_ext),
        .adc_data_32ch_out  (adc_data_out),
        .valid_out          (adcw_valid),
        .data_out           (adcw_data)
    );

    assign adc_valid = adcw_valid;

    F_Frame_Trigger u_frame_trigger (
        .clk            (clk),
        .rst_n          (rst_n),
        .CLK_DIVIDER    (USG_PARAM.frame.CLK_DIVIDER),
        .FRAME_LENGTH   (USG_PARAM.frame.FRAME_LENGTH),
        .ON             (ON),
        .mode_dir       (mode_dir),
        .mode_HF_en_ext (mode_HF_en_ext),
        .frame_start    (frame_start),
        .mode_HF_en     (mode_HF_en)
    );

    logic [N_CH_LF-1:0][MMF_DATA_WIDTH-1:0] lf_din;
    logic [N_CH_HF-1:0][MMF_DATA_WIDTH-1:0] hf_din;
    always_comb begin
        for (int c = 0; c < N_CH_LF; c++) lf_din[c] = adcw_data[c];
        for (int c = 0; c < N_CH_HF; c++) hf_din[c] = adcw_data[N_CH_LF + c];
    end

    logic                                  mf_valid_lf;
    logic                                  mf_chip_done_lf;
    logic [N_CH_LF-1:0][MMFM_OUT_W-1:0]    mf_data_i_lf, mf_data_q_lf;
    logic                                  mf_valid_hf;
    logic                                  mf_chip_done_hf;
    logic [N_CH_HF-1:0][MMFX_OUT_W-1:0]    mf_data_i_hf, mf_data_q_hf;

    SL_Mixing_Match_Filter u_mmf (
        .clk             (clk),
        .rst_n           (rst_n),
        .frame_start     (frame_start),
        .mode_HF_en      (mode_HF_en),
        .coef            (USG_PARAM.mmf.coef),
        .valid_in        (adcw_valid),
        .din_lf          (lf_din),
        .din_hf          (hf_din),
        .valid_out_lf    (mf_valid_lf),
        .chip_done_out_lf(mf_chip_done_lf),
        .ready_in_lf     (1'b1),
        .dout_lf_i       (mf_data_i_lf),
        .dout_lf_q       (mf_data_q_lf),
        .valid_out_hf    (mf_valid_hf),
        .chip_done_out_hf(mf_chip_done_hf),
        .ready_in_hf     (1'b1),
        .dout_hf_i       (mf_data_i_hf),
        .dout_hf_q       (mf_data_q_hf)
    );

    logic [N_CH_HF-1:0][MMFX_OUT_W-1:0]    mf_data_i, mf_data_q;
    logic                                  mf_valid;
    logic                                  mf_chip_done;
    always_comb begin
        if (mode_HF_en) begin
            mf_data_i    = mf_data_i_hf;
            mf_data_q    = mf_data_q_hf;
            mf_valid     = mf_valid_hf;
            mf_chip_done = mf_chip_done_hf;
        end else begin
            mf_data_i    = mf_data_i_lf;
            mf_data_q    = mf_data_q_lf;
            mf_valid     = mf_valid_lf;
            mf_chip_done = mf_chip_done_lf;
        end
    end

    logic [N_CH_HF-1:0][TOF_FULL_W-1:0]    dg_tofs;
    logic [POSITION_WIDTH-1:0]              dg_pos;
    logic                                   dg_valid;
    logic                                   dg_ready;
    logic                                   dg_done;

    F_DG_Bank_polar #(
        .NCH        (N_CH_HF),
        .TOF_FRAC_W (TOF_FRAC_W),
        .TOF_W      (TOF_FULL_W),
        .POS_W      (POSITION_WIDTH),
        .TH_END     (POSITION_THETA_RANGE - 1),
        .PH_END     (POSITION_PHI_RANGE   - 1)
    ) u_dg (
        .clk                  (clk),
        .rst_n                (rst_n),
        .frame_start          (frame_start),
        .R_START              (r_start_active),
        .NUM_RADII            (USG_PARAM.dg.DG_PSG_NUM_RADII),
        .FS_OVER_C0           (USG_PARAM.dg.DG_CT_FS_OVER_C0),
        .SC_DELTA_R_FINE_CF   (USG_PARAM.dg.SC_DELTA_R_FINE_CF),
        .SC_DELTA_R_COARSE_CF (USG_PARAM.dg.SC_DELTA_R_COARSE_CF),
        .SC_R_FINE_END_CF     (USG_PARAM.dg.SC_R_FINE_END_CF),
        .SC_DELTA_TH_CF       (USG_PARAM.dg.SC_DELTA_TH_CF),
        .SC_DELTA_PH_CF       (USG_PARAM.dg.SC_DELTA_PH_CF),
        .SC_DELTA_PH_FINE_CF  (USG_PARAM.dg.SC_DELTA_PH_FINE_CF),
        .SC_PI_CF             (USG_PARAM.dg.SC_PI_CF),
        .SC_TWO_PI_CF         (USG_PARAM.dg.SC_TWO_PI_CF),
        .SC_R_BOUNDARY        (USG_PARAM.dg.SC_R_BOUNDARY),
        .rx_words             (rx_words_internal),

        .pos_ext_en           (pos_dir),
        .pos_ext_word         (pos_data_ext),
        .pos_ext_valid        (pos_valid_ext),
        .tofs                 (dg_tofs),
        .voxel_pos            (dg_pos),
        .valid                (dg_valid),
        .ready                (dg_ready),
        .done                 (dg_done),
        .init_done            ()
    );

    assign pos_ready = dg_ready;

    logic [12:0] phase_inc_active;
    assign phase_inc_active = mode_HF_en ? PHASE_INC_HF : PHASE_INC;

    SL_Beamformer u_bf (
        .clk            (clk),
        .rst_n          (rst_n),
        .phase_inc      (phase_inc_active),
        .frame_start    (frame_start),
        .mf_data_i      (mf_data_i),
        .mf_data_q      (mf_data_q),
        .mf_valid       (mf_valid),
        .mf_chip_done   (mf_chip_done),
        .dg_tofs        (dg_tofs),
        .dg_valid       (dg_valid),
        .dg_pos         (dg_pos),
        .dg_ready       (dg_ready),
        .voxel_intensity(voxel_value),
        .voxel_sum_i    (),
        .voxel_sum_q    (),
        .voxel_pos      (voxel_pos),
        .voxel_valid    (voxel_valid)
    );

    wire _unused_dg_done = dg_done;

endmodule
