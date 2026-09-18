module F_SC_Mapper_RX
    import USG_parameter_pkg::*;
#(
    parameter int                              CF_TO_R   = SCM_CF_TO_R_SHIFT,
    parameter int                              CF_TO_ANG = SCM_CF_TO_ANG_SHIFT
) (
    input  logic                                clk,
    input  logic                                rst_n,
    input  logic                                frame_start,

    input  logic [SC_DELTA_R_FINE_W-1:0]        DELTA_R_FINE_CF,
    input  logic [SC_DELTA_R_COARSE_W-1:0]      DELTA_R_COARSE_CF,
    input  logic [SC_R_FINE_END_W-1:0]          R_FINE_END_CF,
    input  logic [SC_DELTA_TH_W-1:0]            DELTA_TH_CF,
    input  logic [SC_DELTA_PH_FINE_W-1:0]       DELTA_PH_FINE_CF,
    input  logic signed [SC_PI_CF_W-1:0]        PI_CF,
    input  logic signed [SC_TWO_PI_CF_W-1:0]    TWO_PI_CF,
    input  logic [SC_R_BOUNDARY_W-1:0]          R_BOUNDARY,

    input  logic [20:0]                         SCM_word,
    input  logic                                SCM_valid_in,

    output logic [15:0]                         SCM_r,
    output logic [15:0]                         SCM_theta,
    output logic [15:0]                         SCM_phi,
    output logic                                SCM_valid_out
);

    logic [6:0] r_idx;
    logic [7:0] th_idx;
    logic [5:0] ph_idx;

    assign r_idx  = SCM_word[20:14];
    assign th_idx = SCM_word[13:6];
    assign ph_idx = SCM_word[5:0];

    logic        [22:0] r_cf;

    logic        [20:0] th_cf;

    logic        [27:0] ph_cf_mul;
    logic        [22:0] ph_cf_mod;
    logic signed [23:0] ph_cf_wrapped;

    always_comb begin
        if (r_idx < R_BOUNDARY)
            r_cf = r_idx * DELTA_R_FINE_CF;
        else
            r_cf = R_FINE_END_CF + (r_idx - R_BOUNDARY) * DELTA_R_COARSE_CF;
    end

    assign th_cf      = th_idx * DELTA_TH_CF;
    assign ph_cf_mul  = ph_idx * DELTA_PH_FINE_CF;

    logic [22:0] s1_r_cf;
    logic [20:0] s1_th_cf;
    logic [27:0] s1_ph_mul;
    logic        s1_valid;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s1_r_cf <= '0; s1_th_cf <= '0; s1_ph_mul <= '0; s1_valid <= 1'b0;
        end else if (frame_start) begin
            s1_r_cf <= '0; s1_th_cf <= '0; s1_ph_mul <= '0; s1_valid <= 1'b0;
        end else begin
            s1_r_cf   <= r_cf;
            s1_th_cf  <= th_cf;
            s1_ph_mul <= ph_cf_mul;
            s1_valid  <= SCM_valid_in;
        end
    end

    logic [27:0] ph_mod_acc;
    always_comb begin
        ph_mod_acc = s1_ph_mul;
        for (int k = 5; k >= 0; k--)
            if (ph_mod_acc >= ({5'b0, TWO_PI_CF[22:0]} << k))
                ph_mod_acc = ph_mod_acc - ({5'b0, TWO_PI_CF[22:0]} << k);
    end

    logic [22:0] s2_r_cf;
    logic [20:0] s2_th_cf;
    logic [22:0] s2_ph_mod;
    logic        s2_valid;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s2_r_cf <= '0; s2_th_cf <= '0; s2_ph_mod <= '0; s2_valid <= 1'b0;
        end else if (frame_start) begin
            s2_r_cf <= '0; s2_th_cf <= '0; s2_ph_mod <= '0; s2_valid <= 1'b0;
        end else begin
            s2_r_cf   <= s1_r_cf;
            s2_th_cf  <= s1_th_cf;
            s2_ph_mod <= ph_mod_acc[22:0];
            s2_valid  <= s1_valid;
        end
    end

    always_comb begin
        if ($signed({1'b0, s2_ph_mod}) > PI_CF)
            ph_cf_wrapped = $signed({1'b0, s2_ph_mod}) - TWO_PI_CF;
        else
            ph_cf_wrapped = $signed({1'b0, s2_ph_mod});
    end

    function automatic logic [15:0] rsh_unsigned (input logic [22:0] x,
                                                    input int shift);
        return 16'((x + (23'd1 << (shift - 1))) >> shift);
    endfunction

    function automatic logic signed [15:0] rsh_signed (input logic signed [23:0] x,
                                                         input int shift);
        return 16'($signed((x + (24'sd1 << (shift - 1))) >>> shift));
    endfunction

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            SCM_r         <= 16'd0;
            SCM_theta     <= 16'sd0;
            SCM_phi       <= 16'sd0;
            SCM_valid_out <= 1'b0;
        end else if (frame_start) begin
            SCM_r         <= 16'd0;
            SCM_theta     <= 16'sd0;
            SCM_phi       <= 16'sd0;
            SCM_valid_out <= 1'b0;
        end else begin
            SCM_r         <= rsh_unsigned(s2_r_cf, CF_TO_R);
            SCM_theta     <= rsh_signed($signed({3'd0, s2_th_cf}), CF_TO_ANG);
            SCM_phi       <= rsh_signed(ph_cf_wrapped,             CF_TO_ANG);
            SCM_valid_out <= s2_valid;
        end
    end

endmodule
