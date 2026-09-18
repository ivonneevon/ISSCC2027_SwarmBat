module JY_ADCD
    import USG_parameter_pkg::*, USG_types::*;
#(
    parameter ADC_WIDTH = 10
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        cmp_out,
    input  wire        ch1_index,
    input  wire        frame_start,

    output reg         ADCD_valid,
    output reg         ADCD_ser1,
    output reg         ADCD_ser2,
    output reg         ADCD_ser3,
    output reg         ADCD_ser4
);

    reg [3:0] master_cnt;
    reg [1:0] ch_cnt_in;
    reg [1:0] ch_cnt_out;
    reg       master_running;
    reg       frame_started;
    reg [1:0] ignore_count;
    reg       ch1_index_d;

    wire ch1_posedge = ch1_index & ~ch1_index_d;
    wire internal_eoc = master_running && (master_cnt == 4'd15);

    wire frame_complete = internal_eoc && (ch_cnt_in == 2'd3);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ch1_index_d    <= 1'b0;
            master_cnt     <= 4'd0;
            master_running <= 1'b0;
            frame_started  <= 1'b0;
            ADCD_valid     <= 1'b0;
        end else if (frame_start) begin
            ch1_index_d    <= 1'b0;
            master_cnt     <= 4'd0;
            master_running <= 1'b0;
            frame_started  <= 1'b0;
            ADCD_valid     <= 1'b0;
        end else begin
            ch1_index_d <= ch1_index;

            if (frame_complete && ignore_count == 2'd0) begin
                ADCD_valid <= 1'b1;
            end else begin
                ADCD_valid <= 1'b0;
            end

            if (!master_running && ch1_index) begin
                master_cnt     <= 4'd1;
                master_running <= 1'b1;
                frame_started  <= 1'b1;
            end else if (master_running) begin
                if (master_cnt == 4'd15) master_cnt <= 4'd0;
                else master_cnt <= master_cnt + 4'd1;
            end
        end
    end

    reg signed [ADC_WIDTH-1:0] shift_in;
    reg signed [ADC_WIDTH-1:0] ch_buf_prev [0:3];
    reg signed [ADC_WIDTH-1:0] ch_buf_curr [0:3];
    wire cmp_sample_time = master_running && (master_cnt >= 4'd5) && (master_cnt <= 4'd14);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_in       <= {ADC_WIDTH{1'b0}};
            ch_cnt_in      <= 2'd0;
            ignore_count   <= 2'd2;
            ch_buf_prev[0] <= {ADC_WIDTH{1'b0}};
            ch_buf_prev[1] <= {ADC_WIDTH{1'b0}};
            ch_buf_prev[2] <= {ADC_WIDTH{1'b0}};
            ch_buf_prev[3] <= {ADC_WIDTH{1'b0}};
            ch_buf_curr[0] <= {ADC_WIDTH{1'b0}};
            ch_buf_curr[1] <= {ADC_WIDTH{1'b0}};
            ch_buf_curr[2] <= {ADC_WIDTH{1'b0}};
            ch_buf_curr[3] <= {ADC_WIDTH{1'b0}};
        end else if (frame_start) begin
            shift_in       <= {ADC_WIDTH{1'b0}};
            ch_cnt_in      <= 2'd0;
            ignore_count   <= 2'd2;
            ch_buf_prev[0] <= {ADC_WIDTH{1'b0}};
            ch_buf_prev[1] <= {ADC_WIDTH{1'b0}};
            ch_buf_prev[2] <= {ADC_WIDTH{1'b0}};
            ch_buf_prev[3] <= {ADC_WIDTH{1'b0}};
            ch_buf_curr[0] <= {ADC_WIDTH{1'b0}};
            ch_buf_curr[1] <= {ADC_WIDTH{1'b0}};
            ch_buf_curr[2] <= {ADC_WIDTH{1'b0}};
            ch_buf_curr[3] <= {ADC_WIDTH{1'b0}};
        end else if (master_running) begin

            if (cmp_sample_time) begin
                shift_in <= {shift_in[ADC_WIDTH-2:0], cmp_out};
            end

            if (internal_eoc) begin
                ch_buf_curr[ch_cnt_in] <= {~shift_in[ADC_WIDTH-1], shift_in[ADC_WIDTH-2:0]};
                ch_cnt_in <= ch_cnt_in + 2'd1;
            end

            if (ch1_posedge && frame_started) begin
                ch_cnt_in <= 2'd0;
                if (ignore_count > 2'd0) begin
                    ignore_count <= ignore_count - 2'd1;
                end

                ch_buf_prev[0] <= ch_buf_curr[0];
                ch_buf_prev[1] <= ch_buf_curr[1];
                ch_buf_prev[2] <= ch_buf_curr[2];
                ch_buf_prev[3] <= ch_buf_curr[3];
            end
        end
    end

    wire signed [ADC_WIDTH-1:0] interp_ch1;
    wire signed [ADC_WIDTH-1:0] interp_ch2;
    wire signed [ADC_WIDTH-1:0] interp_ch3;
    wire signed [ADC_WIDTH-1:0] interp_ch4;

    wire signed [ADC_WIDTH+1:0] ch2_weighted_sum;
    wire signed [ADC_WIDTH+1:0] ch3_weighted_sum;
    wire signed [ADC_WIDTH+1:0] ch4_weighted_sum;

    assign interp_ch1 = ch_buf_curr[0];

    assign ch2_weighted_sum = $signed(ch_buf_prev[1]) + ($signed(ch_buf_curr[1]) << 1) + $signed(ch_buf_curr[1]);
    assign interp_ch2 = ch2_weighted_sum >>> 2;

    assign ch3_weighted_sum = ($signed(ch_buf_prev[2]) << 1) + ($signed(ch_buf_curr[2]) << 1);
    assign interp_ch3 = ch3_weighted_sum >>> 2;

    wire signed [ADC_WIDTH-1:0] shift_in_flipped = {~shift_in[ADC_WIDTH-1], shift_in[ADC_WIDTH-2:0]};
    assign ch4_weighted_sum = ($signed(ch_buf_prev[3]) << 1) + $signed(ch_buf_prev[3]) + $signed(shift_in_flipped);
    assign interp_ch4 = ch4_weighted_sum >>> 2;

    reg signed [ADC_WIDTH-1:0] out_shift [0:3];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_shift[0] <= {ADC_WIDTH{1'b0}};
            out_shift[1] <= {ADC_WIDTH{1'b0}};
            out_shift[2] <= {ADC_WIDTH{1'b0}};
            out_shift[3] <= {ADC_WIDTH{1'b0}};
            ch_cnt_out   <= 2'd0;
        end else if (frame_start) begin
            out_shift[0] <= {ADC_WIDTH{1'b0}};
            out_shift[1] <= {ADC_WIDTH{1'b0}};
            out_shift[2] <= {ADC_WIDTH{1'b0}};
            out_shift[3] <= {ADC_WIDTH{1'b0}};
            ch_cnt_out   <= 2'd0;
        end else if (master_running) begin
            if (internal_eoc) begin
                ch_cnt_out <= ch_cnt_out + 2'd1;
            end

            if (frame_complete) begin
                if (ignore_count == 2'd0) begin
                    out_shift[0] <= interp_ch1;
                    out_shift[1] <= interp_ch2;
                    out_shift[2] <= interp_ch3;
                    out_shift[3] <= interp_ch4;
                end
            end

            else if (ch_cnt_out == 2'd0 && master_cnt >= 4'd0 && master_cnt <= 4'd8) begin
                out_shift[0] <= {out_shift[0][ADC_WIDTH-2:0], 1'b0};
                out_shift[1] <= {out_shift[1][ADC_WIDTH-2:0], 1'b0};
                out_shift[2] <= {out_shift[2][ADC_WIDTH-2:0], 1'b0};
                out_shift[3] <= {out_shift[3][ADC_WIDTH-2:0], 1'b0};
            end
        end
    end

    always @(*) begin
        if (ch_cnt_out == 2'd0 && master_cnt >= 4'd0 && master_cnt <= 4'd9) begin
            ADCD_ser1 = out_shift[0][ADC_WIDTH-1];
            ADCD_ser2 = out_shift[1][ADC_WIDTH-1];
            ADCD_ser3 = out_shift[2][ADC_WIDTH-1];
            ADCD_ser4 = out_shift[3][ADC_WIDTH-1];
        end else begin
            ADCD_ser1 = 1'b0;
            ADCD_ser2 = 1'b0;
            ADCD_ser3 = 1'b0;
            ADCD_ser4 = 1'b0;
        end
    end

endmodule
