module F_SC_Mapper
    import USG_parameter_pkg::*;
#(
    parameter int                          CF_TO_R   = SCM_CF_TO_R_SHIFT,
    parameter int                          CF_TO_ANG = SCM_CF_TO_ANG_SHIFT
) (
    input  logic                                clk,
    input  logic                                rst_n,
    input  logic                                frame_start,

    input  logic [SC_DELTA_R_FINE_W-1:0]        DELTA_R_FINE_CF,
    input  logic [SC_DELTA_R_COARSE_W-1:0]      DELTA_R_COARSE_CF,
    input  logic [SC_R_FINE_END_W-1:0]          R_FINE_END_CF,
    input  logic [SC_DELTA_TH_W-1:0]            DELTA_TH_CF,
    input  logic [SC_DELTA_PH_W-1:0]            DELTA_PH_CF,
    input  logic signed [SC_PI_CF_W-1:0]        PI_CF,
    input  logic signed [SC_TWO_PI_CF_W-1:0]    TWO_PI_CF,
    input  logic [SC_R_BOUNDARY_W-1:0]          R_BOUNDARY,

    input  logic [19:0]                         SCM_word,
    input  logic                                SCM_valid_in,

    output logic [15:0]                         SCM_r,
    output logic [15:0]                         SCM_theta,
    output logic [15:0]                         SCM_phi,
    output logic                                SCM_valid_out
);

    logic [6:0] r_idx;
    logic [6:0] th_idx;
    logic [5:0] ph_idx;

    assign r_idx  = SCM_word[19:13];
    assign th_idx = SCM_word[12:6];
    assign ph_idx = SCM_word[5:0];

    logic        [22:0] r_cf;
    logic        [19:0] th_cf;
    logic        [22:0] ph_cf_raw;
    logic signed [23:0] ph_cf_wrapped;

    always_comb begin
        if (r_idx < R_BOUNDARY)
            r_cf = 23'(r_idx) * 23'(DELTA_R_FINE_CF);
        else
            r_cf = 23'(R_FINE_END_CF) + 23'(r_idx - R_BOUNDARY) * 23'(DELTA_R_COARSE_CF);

        th_cf     = 20'(th_idx) * 20'(DELTA_TH_CF);
        ph_cf_raw = 23'(ph_idx) * 23'(DELTA_PH_CF);

        if ($signed({1'b0, ph_cf_raw}) > PI_CF)
            ph_cf_wrapped = $signed({1'b0, ph_cf_raw}) - TWO_PI_CF;
        else
            ph_cf_wrapped = $signed({1'b0, ph_cf_raw});
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            SCM_valid_out <= 1'b0;
            SCM_r         <= 16'd0;
            SCM_theta     <= 16'd0;
            SCM_phi       <= 16'd0;
        end else if (frame_start) begin
            SCM_valid_out <= 1'b0;
            SCM_r         <= 16'd0;
            SCM_theta     <= 16'd0;
            SCM_phi       <= 16'd0;
        end else begin
            SCM_valid_out <= SCM_valid_in;
            if (SCM_valid_in) begin
                SCM_r     <= 16'((r_cf + (23'd1 << (CF_TO_R   - 1))) >> CF_TO_R);
                SCM_theta <= 16'((th_cf + (20'd1 << (CF_TO_ANG - 1))) >> CF_TO_ANG);
                SCM_phi   <= 16'((ph_cf_wrapped + (24'sd1 <<< (CF_TO_ANG - 1))) >>> CF_TO_ANG);
            end
        end
    end

endmodule
