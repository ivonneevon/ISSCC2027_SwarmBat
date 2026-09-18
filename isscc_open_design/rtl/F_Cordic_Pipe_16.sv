module F_Cordic_Pipe_16
    import USG_parameter_pkg::*, USG_types::*;
(
    input  logic                clk,
    input  logic                rst_n,
    input  logic                frame_start,
    input  logic                enable,

    input  logic signed [15:0]  CEP_angle,
    input  logic                CEP_valid_in,

    output logic signed [15:0]  CEP_cos_val,
    output logic signed [15:0]  CEP_sin_val,
    output logic                CEP_valid_out
);

    localparam int N_ITER   = 14;

    localparam int N_PIPE   = N_ITER - 2;
    localparam int N_STAGES = N_PIPE + 2;

    localparam logic signed [15:0] K_INV_FP   = 16'sd19898;
    localparam logic signed [15:0] PI_AF_FP   = 16'sd25736;
    localparam logic signed [15:0] PI_2_AF_FP = 16'sd12868;

    localparam logic signed [15:0] ATAN_LUT [0:N_ITER-1] = '{
        16'sd6434, 16'sd3798, 16'sd2007, 16'sd1019,
        16'sd511,  16'sd256,  16'sd128,  16'sd64,
        16'sd32,   16'sd16,   16'sd8,    16'sd4,
        16'sd2,    16'sd1
    };

    logic signed [15:0] p_x    [0:N_PIPE];
    logic signed [15:0] p_y    [0:N_PIPE];
    logic signed [15:0] p_z    [0:N_PIPE];
    logic               p_flip [0:N_PIPE];
    logic               p_valid[0:N_PIPE];

    function automatic signed [15:0] sat16(input signed [31:0] v);
        if (v > 32'sd32767)       sat16 = 16'sd32767;
        else if (v < -32'sd32768) sat16 = -16'sd32768;
        else                      sat16 = v[15:0];
    endfunction

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            p_x[0]     <= 16'sd0;
            p_y[0]     <= 16'sd0;
            p_z[0]     <= 16'sd0;
            p_flip[0]  <= 1'b0;
            p_valid[0] <= 1'b0;
        end else if (frame_start) begin
            p_x[0]     <= 16'sd0;
            p_y[0]     <= 16'sd0;
            p_z[0]     <= 16'sd0;
            p_flip[0]  <= 1'b0;
            p_valid[0] <= 1'b0;
        end else if (enable) begin
            p_valid[0] <= CEP_valid_in;
            if (CEP_valid_in) begin
                p_x[0] <= K_INV_FP;
                p_y[0] <= 16'sd0;
                if (CEP_angle > PI_2_AF_FP) begin
                    p_z[0]    <= CEP_angle - PI_AF_FP;
                    p_flip[0] <= 1'b1;
                end else if (CEP_angle < -PI_2_AF_FP) begin
                    p_z[0]    <= CEP_angle + PI_AF_FP;
                    p_flip[0] <= 1'b1;
                end else begin
                    p_z[0]    <= CEP_angle;
                    p_flip[0] <= 1'b0;
                end
            end
        end
    end

    genvar s;
    generate
        for (s = 1; s <= N_PIPE; s = s + 1) begin : gen_cordic_stage
            localparam int I0   = (s <= 2) ? 2*(s-1) : s + 1;
            localparam int I1   = I0 + 1;
            localparam bit HAS2 = (s <= 2);

            wire signed [31:0] x_ext0 = {{16{p_x[s-1][15]}}, p_x[s-1]};
            wire signed [31:0] y_ext0 = {{16{p_y[s-1][15]}}, p_y[s-1]};
            wire               pos0   = (p_z[s-1] >= 16'sd0);
            wire signed [15:0] xa = pos0 ? sat16(x_ext0 - (y_ext0 >>> I0))
                                         : sat16(x_ext0 + (y_ext0 >>> I0));
            wire signed [15:0] ya = pos0 ? sat16(y_ext0 + (x_ext0 >>> I0))
                                         : sat16(y_ext0 - (x_ext0 >>> I0));
            wire signed [15:0] za = pos0 ? (p_z[s-1] - ATAN_LUT[I0])
                                         : (p_z[s-1] + ATAN_LUT[I0]);

            wire signed [15:0] nx, ny, nz;
            if (HAS2) begin : g_two
                wire signed [31:0] x_ext1 = {{16{xa[15]}}, xa};
                wire signed [31:0] y_ext1 = {{16{ya[15]}}, ya};
                wire               pos1   = (za >= 16'sd0);
                assign nx = pos1 ? sat16(x_ext1 - (y_ext1 >>> I1))
                                 : sat16(x_ext1 + (y_ext1 >>> I1));
                assign ny = pos1 ? sat16(y_ext1 + (x_ext1 >>> I1))
                                 : sat16(y_ext1 - (x_ext1 >>> I1));
                assign nz = pos1 ? (za - ATAN_LUT[I1])
                                 : (za + ATAN_LUT[I1]);
            end else begin : g_one
                assign nx = xa;
                assign ny = ya;
                assign nz = za;
            end

            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    p_x[s]     <= 16'sd0;
                    p_y[s]     <= 16'sd0;
                    p_z[s]     <= 16'sd0;
                    p_flip[s]  <= 1'b0;
                    p_valid[s] <= 1'b0;
                end else if (frame_start) begin
                    p_x[s]     <= 16'sd0;
                    p_y[s]     <= 16'sd0;
                    p_z[s]     <= 16'sd0;
                    p_flip[s]  <= 1'b0;
                    p_valid[s] <= 1'b0;
                end else if (enable) begin
                    p_valid[s] <= p_valid[s-1];
                    p_flip[s]  <= p_flip[s-1];
                    if (p_valid[s-1]) begin
                        p_x[s] <= nx;
                        p_y[s] <= ny;
                        p_z[s] <= nz;
                    end
                end
            end
        end
    endgenerate

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            CEP_cos_val   <= 16'sd0;
            CEP_sin_val   <= 16'sd0;
            CEP_valid_out <= 1'b0;
        end else if (frame_start) begin
            CEP_cos_val   <= 16'sd0;
            CEP_sin_val   <= 16'sd0;
            CEP_valid_out <= 1'b0;
        end else if (enable) begin
            CEP_valid_out <= p_valid[N_PIPE];
            if (p_valid[N_PIPE]) begin
                if (p_flip[N_PIPE]) begin
                    CEP_cos_val <= -p_x[N_PIPE];
                    CEP_sin_val <= -p_y[N_PIPE];
                end else begin
                    CEP_cos_val <= p_x[N_PIPE];
                    CEP_sin_val <= p_y[N_PIPE];
                end
            end
        end
    end

endmodule
