module JY_Shared_Waveform_Calc (
    input  wire        mode_HF_en,
    input  wire [11:0] P_PULSE_clk,
    input  wire [7:0]  P_MID_clk,
    input  wire [8:0]  P_NUM_pulse,
    input  wire [4:0]  P_PHASE_CODE_UNIT_pulse,

    output wire [15:0] base_T,
    output wire [15:0] A_p1,
    output wire [15:0] A_p2,
    output wire [15:0] A_p3,
    output wire [15:0] A_p4,
    output wire [15:0] B_p1,
    output wire [15:0] B_p2,
    output wire [15:0] B_p3,
    output wire [15:0] B_p4,
    output wire [15:0] effective_limit,
    output wire [15:0] safe_unit_pulse
);

    wire [15:0] safe_num_pulse_w  = (P_NUM_pulse == 0) ? 16'd1 : {7'd0, P_NUM_pulse};
    wire [15:0] safe_unit_pulse_w = (P_PHASE_CODE_UNIT_pulse == 0) ? 16'd1 : {11'd0, P_PHASE_CODE_UNIT_pulse};
    assign safe_unit_pulse = safe_unit_pulse_w;

    wire [15:0] max_capacity = 16 * safe_unit_pulse_w;
    assign effective_limit = (safe_num_pulse_w < max_capacity) ? safe_num_pulse_w : max_capacity;

    wire [27:0] pulse_hf = {4'd0, P_PULSE_clk} * 16'd43691;
    wire [23:0] mid_hf   = {8'd0, P_MID_clk}   * 16'd43691;

    assign base_T = mode_HF_en ? {4'd0, pulse_hf[27:16]} : {4'd0, P_PULSE_clk};
    wire [15:0] base_m = mode_HF_en ? {8'd0, mid_hf[23:16]} : {8'd0, P_MID_clk};

    assign A_p1 = base_m >> 1;
    assign A_p2 = (base_T >> 1) - (base_m >> 1);
    assign A_p3 = (base_T >> 1) + (base_m * 3) / 2;
    assign A_p4 = base_T - (base_m * 3) / 2;

    assign B_p1 = (base_m * 3) / 2;
    assign B_p2 = (base_T >> 1) - (base_m * 3) / 2;
    assign B_p3 = (base_T >> 1) + (base_m >> 1);
    assign B_p4 = base_T - (base_m >> 1);

endmodule
