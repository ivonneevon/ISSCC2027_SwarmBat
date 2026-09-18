module JY_Pulse_Generator #(
    parameter integer DIP_LENGTH = 4
)(
    input  wire clk,
    input  wire rst_n,
    input  wire Trigger,

    input  wire [15:0] base_T,
    input  wire [15:0] A_p1,
    input  wire [15:0] A_p2,
    input  wire [15:0] A_p3,
    input  wire [15:0] A_p4,
    input  wire [15:0] B_p1,
    input  wire [15:0] B_p2,
    input  wire [15:0] B_p3,
    input  wire [15:0] B_p4,
    input  wire [15:0] effective_limit,
    input  wire [15:0] safe_unit_pulse,

    input  wire [15:0] P_PHASE_CODE,

    output reg  CLK_A_OUT,
    output reg  CLK_B_OUT
);

    localparam ST_IDLE = 1'b0,
               ST_RUN  = 1'b1;

    reg state, next_state_logic;
    reg [15:0] cnt, next_cnt;
    reg [15:0] pulse_cnt, next_pulse_cnt;
    reg [15:0] unit_cnt, next_unit_cnt;
    reg [4:0]  bit_idx, next_bit_idx;

    always @(*) begin
        next_state_logic = state;
        next_cnt         = cnt;
        next_pulse_cnt   = pulse_cnt;
        next_unit_cnt    = unit_cnt;
        next_bit_idx     = bit_idx;

        if (state == ST_RUN) begin
            if (cnt >= base_T - 1) begin
                next_cnt = 0;
                next_pulse_cnt = pulse_cnt + 1;

                if (unit_cnt >= safe_unit_pulse - 1) begin
                    next_unit_cnt = 0;
                    next_bit_idx = bit_idx + 1;
                end else begin
                    next_unit_cnt = unit_cnt + 1;
                end

                if (pulse_cnt >= effective_limit - 1) begin
                    next_state_logic = ST_IDLE;
                end
            end else begin
                next_cnt = cnt + 1;
            end
        end
    end

    wire next_phase  = (next_bit_idx >= 16) ? 1'b0 : P_PHASE_CODE[15 - next_bit_idx];
    wire next_A_high = (next_cnt < A_p1) || ((next_cnt >= A_p2) && (next_cnt < A_p3)) || (next_cnt >= A_p4);
    wire next_B_high = (next_cnt < B_p1) || ((next_cnt >= B_p2) && (next_cnt < B_p3)) || (next_cnt >= B_p4);

    reg       phase_d;
    reg       dip_active;
    reg [3:0] dip_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            phase_d    <= 1'b0;
            dip_active <= 1'b0;
            dip_cnt    <= 4'd0;
        end else if (Trigger) begin
            phase_d    <= 1'b0;
            dip_active <= 1'b0;
            dip_cnt    <= 4'd0;
        end else begin

            if (state == ST_RUN && cnt == 16'd0) begin
                if (next_phase != phase_d) begin
                    dip_active <= 1'b1;
                    dip_cnt    <= 4'd0;
                end
                phase_d <= next_phase;
            end

            else if (dip_active) begin
                if (dip_cnt >= DIP_LENGTH - 1) begin
                    dip_active <= 1'b0;
                    dip_cnt    <= 4'd0;
                end else begin
                    dip_cnt <= dip_cnt + 4'd1;
                end
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_IDLE;
            cnt <= 0; pulse_cnt <= 0; unit_cnt <= 0; bit_idx <= 0;
            CLK_A_OUT <= 1'b1;
            CLK_B_OUT <= 1'b1;
        end else if (Trigger) begin
            state <= ST_RUN;
            cnt <= 0; pulse_cnt <= 0; unit_cnt <= 0; bit_idx <= 0;
            CLK_A_OUT <= 1'b1;
            CLK_B_OUT <= 1'b1;
        end else begin
            state <= next_state_logic;
            cnt <= next_cnt;
            pulse_cnt <= next_pulse_cnt;
            unit_cnt <= next_unit_cnt;
            bit_idx <= next_bit_idx;

            if (next_state_logic == ST_IDLE) begin
                CLK_A_OUT <= 1'b1;
                CLK_B_OUT <= 1'b1;
            end else if (dip_active) begin

                CLK_A_OUT <= 1'b0;
                CLK_B_OUT <= 1'b0;
            end else begin
                CLK_A_OUT <= next_A_high;
                CLK_B_OUT <= next_B_high;
            end
        end
    end

endmodule
