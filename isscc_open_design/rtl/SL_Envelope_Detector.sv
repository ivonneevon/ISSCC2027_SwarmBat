module SL_Envelope_Detector
    import USG_parameter_pkg::*, USG_types::*;
(
    input  logic                              clk,
    input  logic                              rst_n,
    input  logic                              frame_start,

    input  logic signed [ENV_DATA_W-1:0]      din_i,
    input  logic signed [ENV_DATA_W-1:0]      din_q,
    input  logic                              valid_in,
    output logic                              ready_out,

    output logic        [ENV_OUT_W-1:0]       dout,
    output logic                              valid_out,
    input  logic                              ready_in
);

    logic [ENV_DATA_W-1:0] abs_i, abs_q;
    logic [ENV_DATA_W-1:0] max_val, min_val;
    logic [ENV_DATA_W-1:0] magnitude;

    always_comb begin
        abs_i = din_i[ENV_DATA_W-1] ? (~din_i + 1'b1) : din_i;
        abs_q = din_q[ENV_DATA_W-1] ? (~din_q + 1'b1) : din_q;

        if (abs_i >= abs_q) begin
            max_val = abs_i;
            min_val = abs_q;
        end else begin
            max_val = abs_q;
            min_val = abs_i;
        end

        magnitude = max_val + (min_val >> 2) + (min_val >> 3);
    end

    logic [ENV_EXP_W-1:0]  exp_e;
    logic [ENV_MANT_W-1:0] mant_m;
    logic [ENV_DATA_W-1:0] mag_aligned;

    always_comb begin
        exp_e = '0;
        for (int b = ENV_DATA_W-1; b >= 0; b--) begin
            if (magnitude[b]) begin
                exp_e = ENV_EXP_W'(b);
                break;
            end
        end
    end

    always_comb begin
        if (exp_e >= ENV_EXP_W'(ENV_MANT_W))
            mag_aligned = magnitude >> (exp_e - ENV_EXP_W'(ENV_MANT_W));
        else
            mag_aligned = magnitude << (ENV_EXP_W'(ENV_MANT_W) - exp_e);
        mant_m = mag_aligned[ENV_MANT_W-1:0];
    end

    logic [ENV_OUT_W-1:0] enc_intensity;
    assign enc_intensity = {exp_e, mant_m};

    assign ready_out = ready_in || !valid_out;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dout      <= '0;
            valid_out <= 1'b0;
        end else if (frame_start) begin
            dout      <= '0;
            valid_out <= 1'b0;
        end else if (ready_out) begin
            dout      <= enc_intensity;
            valid_out <= valid_in;
        end
    end

endmodule
