module JY_PG_Top
    import USG_parameter_pkg::*, USG_types::*;
(
    input  wire clk,
    input  wire rst_n,
    input  wire frame_start,
    input  wire mode_HF_en,

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

    input  wire [255:0] ch_delay_flat,

    output wire [31:0] out_A_LF,
    output wire [31:0] out_A_HF,
    output wire [31:0] out_B_LF,
    output wire [31:0] out_B_HF
);

    localparam P_NUM_CHANNELS    = 32;
    localparam P_DELAY_WIDTH     = 8;
    localparam P_TX_GLOBAL_DELAY = 160;

    reg frame_start_d_pg;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) frame_start_d_pg <= 1'b0;
        else        frame_start_d_pg <= frame_start;
    end
    wire frame_start_falling_pg = frame_start_d_pg & ~frame_start;

    reg mode_latch;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            mode_latch <= 1'b0;
        else if (frame_start_falling_pg)
            mode_latch <= mode_HF_en;
    end

    wire [11:0]  act_P_PULSE_clk             = mode_latch ? P_PULSE_clk_HF             : P_PULSE_clk_LF;
    wire [7:0]   act_P_MID_clk               = mode_latch ? P_MID_clk_HF               : P_MID_clk_LF;
    wire [8:0]   act_P_NUM_pulse             = mode_latch ? P_NUM_pulse_HF             : P_NUM_pulse_LF;
    wire [15:0]  act_P_PHASE_CODE            = mode_latch ? P_PHASE_CODE_HF            : P_PHASE_CODE_LF;
    wire [4:0]   act_P_PHASE_CODE_UNIT_pulse = mode_latch ? P_PHASE_CODE_UNIT_pulse_HF : P_PHASE_CODE_UNIT_pulse_LF;

    reg [15:0] gt_cnt;
    reg        gt_armed;
    reg        global_trigger;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gt_cnt         <= 16'd0;
            gt_armed       <= 1'b0;
            global_trigger <= 1'b0;
        end else if (frame_start) begin
            gt_cnt         <= 16'd0;
            gt_armed       <= 1'b0;
            global_trigger <= 1'b0;
        end else begin
            global_trigger <= 1'b0;

            if (frame_start_falling_pg) begin

                gt_cnt   <= 16'd0;
                gt_armed <= 1'b1;
            end else if (gt_armed) begin
                if (gt_cnt >= (P_TX_GLOBAL_DELAY - 1)) begin

                    global_trigger <= 1'b1;
                    gt_armed       <= 1'b0;
                end else begin
                    gt_cnt <= gt_cnt + 16'd1;
                end
            end
        end
    end

    reg [13:0] shared_cnt;
    reg        shared_running;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shared_cnt     <= 14'd0;
            shared_running <= 1'b0;
        end else if (global_trigger) begin
            shared_cnt     <= 14'd1;
            shared_running <= 1'b1;
        end else if (shared_running) begin
            shared_cnt <= shared_cnt + 14'd1;
        end
    end

    wire [15:0] w_base_T, w_A_p1, w_A_p2, w_A_p3, w_A_p4;
    wire [15:0] w_B_p1, w_B_p2, w_B_p3, w_B_p4;
    wire [15:0] w_effective_limit, w_safe_unit_pulse;

    JY_Shared_Waveform_Calc u_shared_calc (
        .mode_HF_en(mode_latch),
        .P_PULSE_clk(act_P_PULSE_clk),
        .P_MID_clk(act_P_MID_clk),
        .P_NUM_pulse(act_P_NUM_pulse),
        .P_PHASE_CODE_UNIT_pulse(act_P_PHASE_CODE_UNIT_pulse),
        .base_T(w_base_T),
        .A_p1(w_A_p1), .A_p2(w_A_p2), .A_p3(w_A_p3), .A_p4(w_A_p4),
        .B_p1(w_B_p1), .B_p2(w_B_p2), .B_p3(w_B_p3), .B_p4(w_B_p4),
        .effective_limit(w_effective_limit),
        .safe_unit_pulse(w_safe_unit_pulse)
    );

    wire [31:0] ch_out_A;
    wire [31:0] ch_out_B;

    genvar g;
    generate
        for (g = 0; g < P_NUM_CHANNELS; g = g + 1) begin : CH_ARRAY
            JY_Tx_Channel_Node u_channel (
                .clk(clk),
                .rst_n(rst_n),
                .global_trigger(global_trigger),

                .shared_cnt(shared_cnt),
                .shared_running(shared_running),
                .delay_val(ch_delay_flat[g*8 +: 8]),

                .base_T(w_base_T),
                .A_p1(w_A_p1), .A_p2(w_A_p2), .A_p3(w_A_p3), .A_p4(w_A_p4),
                .B_p1(w_B_p1), .B_p2(w_B_p2), .B_p3(w_B_p3), .B_p4(w_B_p4),
                .effective_limit(w_effective_limit),
                .safe_unit_pulse(w_safe_unit_pulse),
                .P_PHASE_CODE(act_P_PHASE_CODE),
                .CLK_A_OUT(ch_out_A[g]),
                .CLK_B_OUT(ch_out_B[g])
            );
        end
    endgenerate

    assign out_A_LF = mode_latch ? 32'hFFFFFFFF : ch_out_A;
    assign out_A_HF = mode_latch ? ch_out_A    : 32'hFFFFFFFF;
    assign out_B_LF = mode_latch ? 32'hFFFFFFFF : ch_out_B;
    assign out_B_HF = mode_latch ? ch_out_B    : 32'hFFFFFFFF;

endmodule
