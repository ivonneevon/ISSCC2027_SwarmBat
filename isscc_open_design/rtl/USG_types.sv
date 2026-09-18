package USG_types;

    import USG_parameter_pkg::*;

    typedef struct packed {
        logic [POSITION_RADIUS_WIDTH-1:0] radius;
        logic [POSITION_THETA_WIDTH-1:0]  theta;
        logic [POSITION_PHI_WIDTH-1:0]    phi;
    } Voxel_Position;

    typedef struct packed {

        logic        [FS_OVER_C0_W-1:0]                 DG_CT_FS_OVER_C0;

        logic        [PSG_R_START_W-1:0]                DG_PSG_R_START_LF;
        logic        [PSG_R_START_W-1:0]                DG_PSG_R_START_HF;
        logic        [POSITION_RADIUS_WIDTH-1:0]        DG_PSG_NUM_RADII;

        logic        [SC_DELTA_R_FINE_W-1:0]            SC_DELTA_R_FINE_CF;
        logic        [SC_DELTA_R_COARSE_W-1:0]          SC_DELTA_R_COARSE_CF;
        logic        [SC_R_FINE_END_W-1:0]              SC_R_FINE_END_CF;
        logic        [SC_DELTA_TH_W-1:0]                SC_DELTA_TH_CF;
        logic        [SC_DELTA_PH_W-1:0]                SC_DELTA_PH_CF;
        logic        [SC_DELTA_PH_FINE_W-1:0]           SC_DELTA_PH_FINE_CF;
        logic signed [SC_PI_CF_W-1:0]                   SC_PI_CF;
        logic signed [SC_TWO_PI_CF_W-1:0]               SC_TWO_PI_CF;
        logic        [SC_R_BOUNDARY_W-1:0]              SC_R_BOUNDARY;

        logic        [N_CH_CFG*RX_COORD_W-1:0]          rx_coor;
    } F_DG_Config_t;

    typedef struct packed {
        logic [JY_AC_DELAY_LOCAL_W-1:0]   Delay_Local_TX_clk;
        logic [JY_AC_DELAY_TX_CYC_W-1:0]  Delay_TX_cycle_LF;
        logic [JY_AC_DELAY_TX_CYC_W-1:0]  Delay_TX_cycle_HF;
        logic [JY_AC_DELAY_SAMPLE_W-1:0]  Delay_Sample_clk;
        logic [JY_AC_DELAY_RX_W-1:0]      Delay_RX_clk;
    } JY_AC_Config_t;

    typedef struct packed {
        logic [JY_ADCC_DELAY_W-1:0]       Delay_ADC_EN_clk;
    } JY_ADCC_Config_t;

    typedef struct packed {

        logic [JY_PG_PHASE_UNIT_W-1:0]    P_PHASE_CODE_UNIT_pulse_LF;
        logic [JY_PG_PHASE_CODE_W-1:0]    P_PHASE_CODE_LF;
        logic [JY_PG_NUM_PULSE_W-1:0]     P_NUM_pulse_LF;
        logic [JY_PG_MID_W-1:0]           P_MID_clk_LF;
        logic [JY_PG_PULSE_W-1:0]         P_PULSE_clk_LF;

        logic [JY_PG_PHASE_UNIT_W-1:0]    P_PHASE_CODE_UNIT_pulse_HF;
        logic [JY_PG_PHASE_CODE_W-1:0]    P_PHASE_CODE_HF;
        logic [JY_PG_NUM_PULSE_W-1:0]     P_NUM_pulse_HF;
        logic [JY_PG_MID_W-1:0]           P_MID_clk_HF;
        logic [JY_PG_PULSE_W-1:0]         P_PULSE_clk_HF;
    } JY_TPGT_Config_t;

    typedef struct packed {
        logic [JY_PG_CH_DELAY_FLAT_W-1:0] ch_delay_flat;
    } JY_DGD_Config_t;

    typedef struct packed {
        logic [CORR_N_CHIPS-1:0]          coef;
    } SL_MMF_Config_t;

    typedef struct packed {
        logic [FRAME_LENGTH_W-1:0]        FRAME_LENGTH;
        logic [FRAME_DIVIDER_W-1:0]       CLK_DIVIDER;
    } F_Frame_Trigger_Config_t;

    typedef struct packed {
        JY_DGD_Config_t            dgd;
        JY_TPGT_Config_t           tpgt;
        SL_MMF_Config_t            mmf;
        F_Frame_Trigger_Config_t   frame;
        F_DG_Config_t              dg;
        JY_ADCC_Config_t           adcc;
        JY_AC_Config_t             ac;
    } USG_Config_t;

endpackage : USG_types
