module JY_Tx_Channel_Node (
    input  wire clk,
    input  wire rst_n,
    input  wire global_trigger,

    input  wire [13:0] shared_cnt,
    input  wire        shared_running,

    input  wire [7:0] delay_val,

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

    output wire CLK_A_OUT,
    output wire CLK_B_OUT
);

    wire [13:0] delay_target = {delay_val, 6'd0};

    reg armed;
    reg local_trigger;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            armed         <= 1'b0;
            local_trigger <= 1'b0;
        end else begin
            local_trigger <= 1'b0;

            if (global_trigger) begin
                if (delay_val == 8'd0) begin

                    local_trigger <= 1'b1;
                    armed         <= 1'b0;
                end else begin
                    armed <= 1'b1;
                end
            end else if (armed && (shared_cnt >= delay_target)) begin
                local_trigger <= 1'b1;
                armed         <= 1'b0;
            end
        end
    end

    JY_Pulse_Generator u_local_gen (
        .clk(clk),
        .rst_n(rst_n),
        .Trigger(local_trigger),
        .base_T(base_T),
        .A_p1(A_p1), .A_p2(A_p2), .A_p3(A_p3), .A_p4(A_p4),
        .B_p1(B_p1), .B_p2(B_p2), .B_p3(B_p3), .B_p4(B_p4),
        .effective_limit(effective_limit),
        .safe_unit_pulse(safe_unit_pulse),
        .P_PHASE_CODE(P_PHASE_CODE),
        .CLK_A_OUT(CLK_A_OUT),
        .CLK_B_OUT(CLK_B_OUT)
    );

endmodule
