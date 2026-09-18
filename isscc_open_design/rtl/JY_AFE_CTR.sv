`timescale 1ns / 1ps

module JY_AFE_CTR
    import USG_parameter_pkg::*, USG_types::*;
#(
    parameter P_NUM_CHANNELS = 32,
    parameter P_NUM_TRX      = 8
)(
    input  wire clk,
    input  wire rst_n,
    input  wire frame_start,
    input  wire mode_HF_en,

    input  wire [5:0]  Delay_RX_clk,
    input  wire [8:0]  Delay_Sample_clk,
    input  wire [11:0] Delay_TX_cycle_LF,
    input  wire [11:0] Delay_TX_cycle_HF,
    input  wire [6:0]  Delay_Local_TX_clk,

    input  wire [9:0]  Delay_ADC_EN_clk,

    input  wire [11:0] P_PULSE_clk_LF,
    input  wire [7:0]  P_MID_clk_LF,
    input  wire [8:0]  P_NUM_pulse_LF,
    input  wire [15:0] P_PHASE_CODE_LF,
    input  wire [4:0]  P_PHASE_CODE_UNIT_pulse_LF,

    input  wire [11:0] P_PULSE_clk_HF,
    input  wire [7:0]  P_MID_clk_HF,
    input  wire [8:0]  P_NUM_pulse_HF,
    input  wire [15:0] P_PHASE_CODE_HF,
    input  wire [4:0]  P_PHASE_CODE_UNIT_pulse_HF,

    input  wire [(P_NUM_CHANNELS*8)-1:0] ch_delay_flat,

    output wire TRX_MODE_LF,
    output wire SAMPL_EN_LF,
    output wire DCOC_EN_LF,
    output wire PGA_EN_LF,
    output wire LPF_EN_LF,
    output wire ADC_EN_LF,
    output wire RX_SHUNT_LF,
    output wire RX_ON_LF,
    output wire TX_HZ_LF,
    output wire TX_ON_LF,

    output wire TRX_MODE_HF,
    output wire SAMPL_EN_HF,
    output wire DCOC_EN_HF,
    output wire PGA_EN_HF,
    output wire LPF_EN_HF,
    output wire ADC_EN_HF,
    output wire RX_SHUNT_HF,
    output wire RX_ON_HF,
    output wire TX_HZ_HF,
    output wire TX_ON_HF,

    output wire [P_NUM_TRX-1:0] CLK_SMPL_LF,
    output wire [P_NUM_TRX-1:0] CLK_SMPL_HF,
    output wire [P_NUM_TRX-1:0] CLK_CMP_LF,
    output wire [P_NUM_TRX-1:0] CLK_CMP_HF,

    output wire [P_NUM_CHANNELS-1:0] out_A_LF,
    output wire [P_NUM_CHANNELS-1:0] out_B_LF,
    output wire [P_NUM_CHANNELS-1:0] out_A_HF,
    output wire [P_NUM_CHANNELS-1:0] out_B_HF
);

    wire i_CLK_SMPL_LF, i_CLK_SMPL_HF;
    wire i_CLK_CMP_LF,  i_CLK_CMP_HF;

    wire i_ADC_EN_LF, i_ADC_EN_HF;
    assign ADC_EN_LF = i_ADC_EN_LF;
    assign ADC_EN_HF = i_ADC_EN_HF;

    JY_AC u_ac (
        .clk(clk),
        .rst_n(rst_n),
        .frame_start(frame_start),
        .mode_HF_en(mode_HF_en),

        .Delay_RX_clk(Delay_RX_clk),
        .Delay_Sample_clk(Delay_Sample_clk),
        .Delay_TX_cycle_LF(Delay_TX_cycle_LF),
        .Delay_TX_cycle_HF(Delay_TX_cycle_HF),
        .Delay_Local_TX_clk(Delay_Local_TX_clk),

        .TRX_MODE_LF(TRX_MODE_LF),
        .SAMPL_EN_LF(SAMPL_EN_LF),
        .DCOC_EN_LF(DCOC_EN_LF),
        .PGA_EN_LF(PGA_EN_LF),
        .LPF_EN_LF(LPF_EN_LF),
        .ADC_EN_LF(i_ADC_EN_LF),
        .RX_SHUNT_LF(RX_SHUNT_LF),
        .RX_ON_LF(RX_ON_LF),
        .TX_HZ_LF(TX_HZ_LF),
        .TX_ON_LF(TX_ON_LF),

        .TRX_MODE_HF(TRX_MODE_HF),
        .SAMPL_EN_HF(SAMPL_EN_HF),
        .DCOC_EN_HF(DCOC_EN_HF),
        .PGA_EN_HF(PGA_EN_HF),
        .LPF_EN_HF(LPF_EN_HF),
        .ADC_EN_HF(i_ADC_EN_HF),
        .RX_SHUNT_HF(RX_SHUNT_HF),
        .RX_ON_HF(RX_ON_HF),
        .TX_HZ_HF(TX_HZ_HF),
        .TX_ON_HF(TX_ON_HF)
    );

    JY_ADCC u_adcc (
        .rst_n(rst_n),
        .CLK_IN(clk),
        .ADC_EN_LF(i_ADC_EN_LF),
        .ADC_EN_HF(i_ADC_EN_HF),
        .frame_start(frame_start),
        .mode_HF_en(mode_HF_en),
        .Delay_ADC_EN_clk(Delay_ADC_EN_clk),
        .CLK_SMPL_LF(i_CLK_SMPL_LF),
        .CLK_SMPL_HF(i_CLK_SMPL_HF),
        .CLK_CMP_LF(i_CLK_CMP_LF),
        .CLK_CMP_HF(i_CLK_CMP_HF)
    );

    JY_PG_Top u_pg (
        .clk(clk),
        .rst_n(rst_n),
        .frame_start(frame_start),
        .mode_HF_en(mode_HF_en),

        .P_PULSE_clk_LF(P_PULSE_clk_LF),
        .P_MID_clk_LF(P_MID_clk_LF),
        .P_NUM_pulse_LF(P_NUM_pulse_LF),
        .P_PHASE_CODE_LF(P_PHASE_CODE_LF),
        .P_PHASE_CODE_UNIT_pulse_LF(P_PHASE_CODE_UNIT_pulse_LF),

        .P_PULSE_clk_HF(P_PULSE_clk_HF),
        .P_MID_clk_HF(P_MID_clk_HF),
        .P_NUM_pulse_HF(P_NUM_pulse_HF),
        .P_PHASE_CODE_HF(P_PHASE_CODE_HF),
        .P_PHASE_CODE_UNIT_pulse_HF(P_PHASE_CODE_UNIT_pulse_HF),

        .ch_delay_flat(ch_delay_flat),

        .out_A_LF(out_A_LF), .out_A_HF(out_A_HF),
        .out_B_LF(out_B_LF), .out_B_HF(out_B_HF)
    );

    assign CLK_SMPL_LF = {P_NUM_TRX{i_CLK_SMPL_LF}};
    assign CLK_SMPL_HF = {P_NUM_TRX{i_CLK_SMPL_HF}};
    assign CLK_CMP_LF  = {P_NUM_TRX{i_CLK_CMP_LF}};
    assign CLK_CMP_HF  = {P_NUM_TRX{i_CLK_CMP_HF}};

endmodule
