`timescale 1ns / 1ps

module JY_AC (
    input  wire clk,
    input  wire rst_n,
    input  wire frame_start,
    input  wire mode_HF_en,

    input  wire [5:0]  Delay_RX_clk,
    input  wire [8:0]  Delay_Sample_clk,
    input  wire [11:0] Delay_TX_cycle_LF,
    input  wire [11:0] Delay_TX_cycle_HF,
    input  wire [6:0]  Delay_Local_TX_clk,

    output reg TRX_MODE_LF,
    output reg SAMPL_EN_LF,
    output reg DCOC_EN_LF,
    output reg PGA_EN_LF,
    output reg LPF_EN_LF,
    output reg ADC_EN_LF,
    output reg RX_SHUNT_LF,
    output reg RX_ON_LF,
    output reg TX_HZ_LF,
    output reg TX_ON_LF,

    output reg TRX_MODE_HF,
    output reg SAMPL_EN_HF,
    output reg DCOC_EN_HF,
    output reg PGA_EN_HF,
    output reg LPF_EN_HF,
    output reg ADC_EN_HF,
    output reg RX_SHUNT_HF,
    output reg RX_ON_HF,
    output reg TX_HZ_HF,
    output reg TX_ON_HF
);

    reg mode_latch;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            mode_latch <= 1'b0;
        else if (frame_start)
            mode_latch <= mode_HF_en;
    end

    wire [11:0] Delay_TX_cycle = mode_latch ? Delay_TX_cycle_HF : Delay_TX_cycle_LF;

    localparam ST_INIT           = 4'd0,
               ST_TX_START       = 4'd1,
               ST_TX_DELAY_1US   = 4'd2,
               ST_TX_SAMPL_ON    = 4'd3,
               ST_TX_SAMPL_WAIT  = 4'd4,
               ST_TX_IDLE        = 4'd5,
               ST_RX_START       = 4'd6,
               ST_RX_WAIT_PGA    = 4'd7,
               ST_RX_WAIT_LPF    = 4'd8,
               ST_RX_WAIT_ADC    = 4'd9,
               ST_RX_IDLE        = 4'd10,
               ST_STANDBY        = 4'd15;

    reg [3:0] state, next_state;
    reg [15:0] delay_cnt;

    wire [15:0] safe_delay_rx     = {10'd0, Delay_RX_clk};
    wire [15:0] safe_delay_sample = {7'd0, Delay_Sample_clk};

    wire [23:0] Delay_TX_clk      = {12'd0, Delay_TX_cycle} * 24'd625;
    wire [23:0] safe_delay_tx_cyc = Delay_TX_clk;
    wire [15:0] safe_delay_local  = {9'd0, Delay_Local_TX_clk};

    wire done_rx_pga   = (delay_cnt >= ((Delay_RX_clk >= 3) ? safe_delay_rx - 16'd3 : 16'd0));
    wire done_rx_lpf   = (delay_cnt >= (safe_delay_rx - 16'd1));
    wire done_rx_adc   = (delay_cnt >= (safe_delay_rx - 16'd1));
    wire done_tx_sampl = (delay_cnt >= ((Delay_RX_clk >= 4) ? safe_delay_rx - 16'd4 : 16'd0));
    wire done_tx_hold  = (delay_cnt >= (safe_delay_sample - 16'd1));

    reg i_TRX_MODE;
    reg i_SAMPL_EN, i_DCOC_EN, i_PGA_EN, i_LPF_EN, i_ADC_EN;
    reg LF_RX_SHUNT_reg, LF_RX_ON_reg, LF_TX_HZ_reg, LF_TX_ON_reg;
    reg HF_RX_SHUNT_reg, HF_RX_ON_reg, HF_TX_HZ_reg, HF_TX_ON_reg;

    reg mode_latch_d;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) mode_latch_d <= 1'b0;
        else        mode_latch_d <= mode_latch;
    end
    wire mode_just_flipped = (mode_latch != mode_latch_d);

    reg frame_start_d;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) frame_start_d <= 1'b0;
        else        frame_start_d <= frame_start;
    end
    wire frame_start_falling = frame_start_d & ~frame_start;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_STANDBY;
        end else if (frame_start_falling) begin
            state <= ST_TX_START;
        end else if (!frame_start) begin
            state <= next_state;
        end
    end

    reg [23:0] trx_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            i_TRX_MODE <= 1'b0;
            trx_cnt    <= 24'd0;
        end else if (frame_start_falling) begin
            i_TRX_MODE <= 1'b1;
            trx_cnt    <= 24'd0;
        end else if (!frame_start) begin
            if (i_TRX_MODE) begin
                if (trx_cnt >= (safe_delay_tx_cyc - 24'd1)) begin
                    i_TRX_MODE <= 1'b0;
                end else begin
                    trx_cnt <= trx_cnt + 24'd1;
                end
            end
        end
    end

    reg trx_mode_d;
    wire trx_rising  = i_TRX_MODE & ~trx_mode_d;
    wire trx_falling_wire = (i_TRX_MODE && (trx_cnt >= (safe_delay_tx_cyc - 24'd1)));

    localparam SW_IDLE    = 3'd0,
               SW_TX_S1   = 3'd1,
               SW_TX_S2   = 3'd2,
               SW_TX_S3   = 3'd3,
               SW_RX_S1   = 3'd4,
               SW_RX_S2   = 3'd5,
               SW_RX_S3   = 3'd6;

    reg [2:0]  sw_state;
    reg [15:0] sw_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            trx_mode_d <= 1'b0;
            sw_state   <= SW_IDLE;
            sw_cnt     <= 16'd0;

            LF_RX_SHUNT_reg <= 1'b1; LF_RX_ON_reg <= 1'b0; LF_TX_HZ_reg <= 1'b0; LF_TX_ON_reg <= 1'b1;
            HF_RX_SHUNT_reg <= 1'b1; HF_RX_ON_reg <= 1'b0; HF_TX_HZ_reg <= 1'b0; HF_TX_ON_reg <= 1'b1;
        end else if (mode_just_flipped) begin

            sw_state   <= SW_IDLE;
            sw_cnt     <= 16'd0;
            trx_mode_d <= 1'b0;
        end else if (!frame_start) begin
            trx_mode_d <= i_TRX_MODE;
            case (sw_state)
                SW_IDLE: begin
                    if (trx_rising) begin
                        if (mode_latch == 1'b0) LF_RX_SHUNT_reg <= 1'b1;
                        else                    HF_RX_SHUNT_reg <= 1'b1;
                        sw_state <= SW_TX_S1;
                        sw_cnt   <= 16'd0;
                    end else if (trx_falling_wire) begin
                        if (mode_latch == 1'b0) LF_TX_ON_reg <= 1'b0;
                        else                    HF_TX_ON_reg <= 1'b0;
                        sw_state <= SW_RX_S1;
                        sw_cnt   <= 16'd0;
                    end
                end
                SW_TX_S1: begin
                    if (sw_cnt >= (safe_delay_local - 16'd1)) begin
                        if (mode_latch == 1'b0) LF_RX_ON_reg <= 1'b0;
                        else                    HF_RX_ON_reg <= 1'b0;
                        sw_state <= SW_TX_S2;
                        sw_cnt   <= 16'd0;
                    end else sw_cnt <= sw_cnt + 16'd1;
                end
                SW_TX_S2: begin
                    if (sw_cnt >= (safe_delay_local - 16'd1)) begin
                        if (mode_latch == 1'b0) LF_TX_HZ_reg <= 1'b0;
                        else                    HF_TX_HZ_reg <= 1'b0;
                        sw_state <= SW_TX_S3;
                        sw_cnt   <= 16'd0;
                    end else sw_cnt <= sw_cnt + 16'd1;
                end
                SW_TX_S3: begin
                    if (sw_cnt >= (safe_delay_local - 16'd1)) begin
                        if (mode_latch == 1'b0) LF_TX_ON_reg <= 1'b1;
                        else                    HF_TX_ON_reg <= 1'b1;
                        sw_state <= SW_IDLE;
                        sw_cnt   <= 16'd0;
                    end else sw_cnt <= sw_cnt + 16'd1;
                end
                SW_RX_S1: begin
                    if (sw_cnt >= (safe_delay_local - 16'd1)) begin
                        if (mode_latch == 1'b0) LF_TX_HZ_reg <= 1'b1;
                        else                    HF_TX_HZ_reg <= 1'b1;
                        sw_state <= SW_RX_S2;
                        sw_cnt   <= 16'd0;
                    end else sw_cnt <= sw_cnt + 16'd1;
                end
                SW_RX_S2: begin
                    if (sw_cnt >= (safe_delay_local - 16'd1)) begin
                        if (mode_latch == 1'b0) LF_RX_ON_reg <= 1'b1;
                        else                    HF_RX_ON_reg <= 1'b1;
                        sw_state <= SW_RX_S3;
                        sw_cnt   <= 16'd0;
                    end else sw_cnt <= sw_cnt + 16'd1;
                end
                SW_RX_S3: begin
                    if (sw_cnt >= (safe_delay_local - 16'd1)) begin
                        if (mode_latch == 1'b0) LF_RX_SHUNT_reg <= 1'b0;
                        else                    HF_RX_SHUNT_reg <= 1'b0;
                        sw_state <= SW_IDLE;
                        sw_cnt   <= 16'd0;
                    end else sw_cnt <= sw_cnt + 16'd1;
                end
                default: sw_state <= SW_IDLE;
            endcase
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            ST_STANDBY:       next_state = ST_STANDBY;
            ST_INIT:          next_state = ST_TX_START;
            ST_TX_START:      next_state = ST_TX_DELAY_1US;
            ST_TX_DELAY_1US:  if (done_tx_sampl) next_state = ST_TX_SAMPL_ON;
                              else if (!i_TRX_MODE) next_state = ST_RX_START;
            ST_TX_SAMPL_ON:   next_state = ST_TX_SAMPL_WAIT;
            ST_TX_SAMPL_WAIT: if (done_tx_hold) next_state = ST_TX_IDLE;
                              else if (!i_TRX_MODE) next_state = ST_RX_START;
            ST_TX_IDLE:       if (!i_TRX_MODE) next_state = ST_RX_START;

            ST_RX_START:      next_state = ST_RX_WAIT_PGA;
            ST_RX_WAIT_PGA:   if (done_rx_pga) next_state = ST_RX_WAIT_LPF;
                              else if (i_TRX_MODE) next_state = ST_TX_START;
            ST_RX_WAIT_LPF:   if (done_rx_lpf) next_state = ST_RX_WAIT_ADC;
                              else if (i_TRX_MODE) next_state = ST_TX_START;
            ST_RX_WAIT_ADC:   if (done_rx_adc) next_state = ST_RX_IDLE;
                              else if (i_TRX_MODE) next_state = ST_TX_START;
            ST_RX_IDLE:       if (i_TRX_MODE) next_state = ST_TX_START;
            default:          next_state = ST_INIT;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            delay_cnt  <= 16'd0;
            i_SAMPL_EN <= 1'b0; i_DCOC_EN <= 1'b0; i_PGA_EN <= 1'b0; i_LPF_EN <= 1'b0; i_ADC_EN <= 1'b0;
        end else if (frame_start) begin
            i_SAMPL_EN <= 1'b0; i_DCOC_EN <= 1'b0; i_PGA_EN <= 1'b0; i_LPF_EN <= 1'b0; i_ADC_EN <= 1'b0;
        end else if (i_TRX_MODE == 1'b1 && next_state == ST_TX_START && state != ST_TX_START) begin
            delay_cnt  <= 16'd0;
            i_SAMPL_EN <= 1'b0; i_DCOC_EN <= 1'b0; i_PGA_EN <= 1'b0; i_LPF_EN <= 1'b0; i_ADC_EN <= 1'b0;
        end else if (!frame_start) begin
            case (state)
                ST_STANDBY: begin
                    delay_cnt  <= 16'd0;
                    i_SAMPL_EN <= 1'b0; i_DCOC_EN <= 1'b0; i_PGA_EN <= 1'b0; i_LPF_EN <= 1'b0; i_ADC_EN <= 1'b0;
                end
                ST_INIT: delay_cnt <= 16'd0;
                ST_TX_START: begin
                    delay_cnt  <= 16'd0;
                    i_SAMPL_EN <= 1'b0; i_DCOC_EN <= 1'b0; i_PGA_EN <= 1'b0; i_LPF_EN <= 1'b0; i_ADC_EN <= 1'b0;
                end
                ST_TX_DELAY_1US: delay_cnt <= delay_cnt + 16'd1;
                ST_TX_SAMPL_ON: begin
                    delay_cnt  <= 16'd0;
                    i_SAMPL_EN <= 1'b1; i_DCOC_EN <= 1'b1;
                end
                ST_TX_SAMPL_WAIT: begin
                    if (done_tx_hold) begin
                        i_SAMPL_EN <= 1'b0;
                        delay_cnt  <= 16'd0;
                    end else delay_cnt <= delay_cnt + 16'd1;
                end
                ST_TX_IDLE: begin delay_cnt <= 16'd0; i_SAMPL_EN <= 1'b0; end

                ST_RX_START: begin delay_cnt <= 16'd0; i_DCOC_EN <= 1'b1; i_SAMPL_EN <= 1'b0; end
                ST_RX_WAIT_PGA: begin
                    delay_cnt <= delay_cnt + 16'd1;
                    if (done_rx_pga) begin i_PGA_EN <= 1'b1; delay_cnt <= 16'd0; end
                end
                ST_RX_WAIT_LPF: begin
                    delay_cnt <= delay_cnt + 16'd1;
                    if (done_rx_lpf) begin i_LPF_EN <= 1'b1; delay_cnt <= 16'd0; end
                end
                ST_RX_WAIT_ADC: begin
                    delay_cnt <= delay_cnt + 16'd1;
                    if (done_rx_adc) begin i_ADC_EN <= 1'b1; delay_cnt <= 16'd0; end
                end
                ST_RX_IDLE: delay_cnt <= 16'd0;
            endcase
        end
    end

    always @(*) begin

        RX_SHUNT_LF = LF_RX_SHUNT_reg;
        RX_ON_LF    = LF_RX_ON_reg;
        TX_HZ_LF    = LF_TX_HZ_reg;
        TX_ON_LF    = LF_TX_ON_reg;
        RX_SHUNT_HF = HF_RX_SHUNT_reg;
        RX_ON_HF    = HF_RX_ON_reg;
        TX_HZ_HF    = HF_TX_HZ_reg;
        TX_ON_HF    = HF_TX_ON_reg;

        if (mode_latch == 1'b0) begin
            TRX_MODE_LF = i_TRX_MODE;
            SAMPL_EN_LF = i_SAMPL_EN;
            DCOC_EN_LF  = i_DCOC_EN;
            PGA_EN_LF   = i_PGA_EN;
            LPF_EN_LF   = i_LPF_EN;
            ADC_EN_LF   = i_ADC_EN;
            TRX_MODE_HF = 1'b0;
            SAMPL_EN_HF = 1'b0;
            DCOC_EN_HF  = 1'b0;
            PGA_EN_HF   = 1'b0;
            LPF_EN_HF   = 1'b0;
            ADC_EN_HF   = 1'b0;
        end else begin
            TRX_MODE_HF = i_TRX_MODE;
            SAMPL_EN_HF = i_SAMPL_EN;
            DCOC_EN_HF  = i_DCOC_EN;
            PGA_EN_HF   = i_PGA_EN;
            LPF_EN_HF   = i_LPF_EN;
            ADC_EN_HF   = i_ADC_EN;
            TRX_MODE_LF = 1'b0;
            SAMPL_EN_LF = 1'b0;
            DCOC_EN_LF  = 1'b0;
            PGA_EN_LF   = 1'b0;
            LPF_EN_LF   = 1'b0;
            ADC_EN_LF   = 1'b0;
        end
    end

endmodule
