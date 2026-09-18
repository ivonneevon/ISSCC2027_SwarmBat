module JY_ADCC
    import USG_parameter_pkg::*, USG_types::*;
(
    input  wire rst_n,
    input  wire CLK_IN,

    input  wire ADC_EN_LF,
    input  wire ADC_EN_HF,
    input  wire frame_start,
    input  wire mode_HF_en,

    input  wire [9:0] Delay_ADC_EN_clk,

    output reg  CLK_SMPL_LF,
    output reg  CLK_SMPL_HF,
    output wire CLK_CMP_LF,
    output wire CLK_CMP_HF
);

    localparam ST_WAIT_EN  = 2'd0,
               ST_DELAY    = 2'd1,
               ST_RUN      = 2'd2;

    reg [1:0]  state;
    reg [15:0] delay_cnt;
    reg [3:0]  cnt;

    reg mode_latch;
    always @(posedge CLK_IN or negedge rst_n) begin
        if (!rst_n)            mode_latch <= 1'b0;
        else if (frame_start)  mode_latch <= mode_HF_en;
    end

    wire ADC_EN_active = ADC_EN_LF | ADC_EN_HF;

    wire [15:0] safe_delay_adc_en = {6'd0, Delay_ADC_EN_clk};

    reg cmp_en_latch;
    always @(negedge CLK_IN or negedge rst_n) begin
        if (!rst_n) begin
            cmp_en_latch <= 1'b0;
        end else begin
            if (state == ST_RUN && (cnt >= 4'd4 && cnt <= 4'd14)) begin
                cmp_en_latch <= 1'b1;
            end else begin
                cmp_en_latch <= 1'b0;
            end
        end
    end

    wire i_CLK_CMP = cmp_en_latch & CLK_IN;

    reg i_CLK_SMPL;

    always @(posedge CLK_IN or negedge rst_n) begin
        if (!rst_n) begin
            state       <= ST_WAIT_EN;
            delay_cnt   <= 16'd0;
            cnt         <= 4'd0;
            i_CLK_SMPL  <= 1'b0;
        end else if (frame_start) begin
            state       <= ST_WAIT_EN;
            delay_cnt   <= 16'd0;
            cnt         <= 4'd0;
            i_CLK_SMPL  <= 1'b0;
        end else begin
            if (!ADC_EN_active) begin
                state       <= ST_WAIT_EN;
                delay_cnt   <= 16'd0;
                cnt         <= 4'd0;
                i_CLK_SMPL  <= 1'b0;
            end else begin
                case (state)
                    ST_WAIT_EN: begin
                        state     <= ST_DELAY;
                        delay_cnt <= 16'd1;
                    end
                    ST_DELAY: begin
                        if (delay_cnt >= safe_delay_adc_en) begin
                            state      <= ST_RUN;
                            cnt        <= 4'd0;
                            i_CLK_SMPL <= 1'b1;
                        end else begin
                            delay_cnt <= delay_cnt + 16'd1;
                        end
                    end
                    ST_RUN: begin
                        cnt <= cnt + 4'd1;
                        if (cnt == 4'd15 || cnt < 4'd3) begin
                            i_CLK_SMPL <= 1'b1;
                        end else begin
                            i_CLK_SMPL <= 1'b0;
                        end
                    end
                endcase
            end
        end
    end

    always @(*) begin
        if (mode_latch == 1'b0) begin
            CLK_SMPL_LF = i_CLK_SMPL;
            CLK_SMPL_HF = 1'b0;
        end else begin
            CLK_SMPL_LF = 1'b0;
            CLK_SMPL_HF = i_CLK_SMPL;
        end
    end

    assign CLK_CMP_LF = (mode_latch == 1'b0) ? i_CLK_CMP : 1'b0;
    assign CLK_CMP_HF = (mode_latch == 1'b1) ? i_CLK_CMP : 1'b0;

endmodule
