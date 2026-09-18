package USG_parameter_pkg;

    parameter POSITION_THETA_RANGE   = 128;
    parameter POSITION_PHI_RANGE     = 64;
    parameter POSITION_THETA_WIDTH   = 7;
    parameter POSITION_PHI_WIDTH     = 6;
    parameter POSITION_RADIUS_WIDTH  = 7;
    parameter POSITION_WIDTH         = 20;

    parameter RX_COORD_W             = 21;

    parameter N_CH_LF                = 16;
    parameter N_CH_HF                = 16;
    parameter N_CH_ALL               = N_CH_LF + N_CH_HF;

    parameter N_CH                   = 16;

    parameter N_CH_CFG               = 32;

    parameter ADC_WIDTH              = 10;
    parameter ADCW_N_SLICE_LF        = N_CH_LF / 4;
    parameter ADCW_N_SLICE_HF        = N_CH_HF / 4;
    parameter ADCW_N_SLICE_TOTAL     = ADCW_N_SLICE_LF + ADCW_N_SLICE_HF;

    parameter MF_DATA_W              = 22;
    parameter MMF_DATA_WIDTH         = ADC_WIDTH;

    parameter MMFM_N_GROUPS          = 2;
    parameter MMFM_CH_PER_GROUP      = N_CH_LF / MMFM_N_GROUPS;
    parameter MMFM_N_BRANCHES        = MMFM_CH_PER_GROUP * 2;
    parameter MMFM_BR_W              = 5;
    parameter MMFM_OUT_W             = ADC_WIDTH + 12;

    parameter MMFX_OUT_W             = ADC_WIDTH + 12;
    parameter MMFX_SAMP_PER_CHIP     = 250;
    parameter MMFX_SAMP_CNT_W        = 8;

    parameter CORR_DATA_WIDTH        = ADC_WIDTH;
    parameter CORR_N_BRANCHES        = MMFM_N_BRANCHES;
    parameter CORR_N_CHIPS           = 15;
    parameter CORR_SAMPS             = 250;
    parameter CORR_ACC_W             = ADC_WIDTH + 8;
    parameter CORR_OUT_W             = ADC_WIDTH + 12;
    parameter CORR_CNT_W             = 8;
    parameter CORR_FILL_W            = 4;
    parameter CORR_BR_W              = 5;

    parameter LO_PERIOD              = 25;
    parameter LO_CNT_W               = 5;
    parameter BM_DATA_WIDTH          = 16;

    parameter TOF_FRAC_W             = 4;
    parameter TOF_FULL_W             = 20;

    parameter SC_DELTA_R_FINE_W      = 13;
    parameter SC_DELTA_R_COARSE_W    = 17;
    parameter SC_R_FINE_END_W        = 18;
    parameter SC_DELTA_TH_W          = 13;
    parameter SC_DELTA_PH_W          = 17;
    parameter SC_DELTA_PH_FINE_W     = 22;
    parameter SC_PI_CF_W             = 24;
    parameter SC_TWO_PI_CF_W         = 24;
    parameter SC_R_BOUNDARY_W        = 7;

    parameter SCM_CF_TO_R_SHIFT      = 8;
    parameter SCM_CF_TO_ANG_SHIFT    = 7;

    parameter FS_OVER_C0_W           = 16;
    parameter PSG_R_START_W          = 7;

    parameter IQ_BUF_DEPTH           = 64;
    parameter IQ_BUF_ADDR_W          = 6;

    parameter DA_N_SRAMS             = 2;
    parameter DA_CH_PER_SRAM         = N_CH / DA_N_SRAMS;

    parameter DA_SRAM_AW             = 10;
    parameter DA_SRAM_DW             = 2 * MF_DATA_W;
    parameter DA_COARSE_W            = 7;
    parameter DA_TOF_INT_W           = TOF_FULL_W - TOF_FRAC_W;
    parameter DA_RECIP               = 1049;
    parameter DA_RECIP_SHIFT         = 18;

    parameter ANGLE_W                = 16;
    parameter CORDIC_ITER            = 8;
    parameter CORDIC_OUT_W           = MF_DATA_W + 2;

    parameter PR_DATA_W              = MF_DATA_W;
    parameter PR_ANGLE_W             = ANGLE_W;
    parameter PR_N_ITER              = CORDIC_ITER;
    parameter PR_INT_W               = PR_DATA_W + 2;
    parameter PR_UNROLL              = 2;
    parameter PR_N_STAGES            = PR_N_ITER / PR_UNROLL;

    parameter [12:0] PHASE_INC       = 13'd5243;
    parameter [12:0] PHASE_INC_HF    = 13'd7864;

    parameter ADDER_OUT_W            = CORDIC_OUT_W + 6;
    parameter ENV_DATA_W             = ADDER_OUT_W;
    parameter ENV_EXP_W              = 5;
    parameter ENV_MANT_W             = 11;
    parameter ENV_OUT_W              = ENV_EXP_W + ENV_MANT_W;
    parameter BF_POS_PIPE_DEPTH      = (PR_N_ITER / PR_UNROLL) + 1;

    parameter PSG_NUM_RADII          = 30;
    parameter [6:0] PSG_R_START_LF   = 7'd35;

    parameter FRAME_LENGTH_W         = 15;
    parameter FRAME_DIVIDER_W        = 7;

    parameter JY_AC_DELAY_RX_W       = 6;
    parameter JY_AC_DELAY_SAMPLE_W   = 9;
    parameter JY_AC_DELAY_TX_CYC_W   = 12;
    parameter JY_AC_DELAY_LOCAL_W    = 7;

    parameter JY_ADCC_DELAY_W        = 10;

    parameter JY_PG_NUM_CHANNELS     = 32;
    parameter JY_PG_PULSE_W          = 12;
    parameter JY_PG_MID_W            = 8;
    parameter JY_PG_NUM_PULSE_W      = 9;
    parameter JY_PG_PHASE_CODE_W     = 16;
    parameter JY_PG_PHASE_UNIT_W     = 5;
    parameter JY_PG_CH_DELAY_FLAT_W  = JY_PG_NUM_CHANNELS * 8;

endpackage : USG_parameter_pkg
