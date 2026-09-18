module F_Cordic_2S
    import USG_parameter_pkg::*, USG_types::*;
(
    input  logic                clk,
    input  logic                rst_n,
    input  logic                frame_start,
    input  logic                enable,

    input  logic signed [15:0]  theta,
    input  logic signed [15:0]  phi,
    input  logic                valid_in,

    output logic signed [15:0]  ux,
    output logic signed [15:0]  uy,
    output logic signed [15:0]  uz,
    output logic                valid_out
);

    logic signed [15:0] cos_th, sin_th;
    logic signed [15:0] cos_ph, sin_ph;
    logic               valid_th, valid_ph;

    F_Cordic_Pipe_16 u_th (
        .clk          (clk),
        .rst_n        (rst_n),
        .frame_start  (frame_start),
        .enable       (enable),
        .CEP_angle    (theta),
        .CEP_valid_in (valid_in),
        .CEP_cos_val  (cos_th),
        .CEP_sin_val  (sin_th),
        .CEP_valid_out(valid_th)
    );

    F_Cordic_Pipe_16 u_ph (
        .clk          (clk),
        .rst_n        (rst_n),
        .frame_start  (frame_start),
        .enable       (enable),
        .CEP_angle    (phi),
        .CEP_valid_in (valid_in),
        .CEP_cos_val  (cos_ph),
        .CEP_sin_val  (sin_ph),
        .CEP_valid_out(valid_ph)
    );

    logic signed [31:0] ux_full, uy_full;

    assign ux_full = $signed(sin_th) * $signed(cos_ph);
    assign uy_full = $signed(sin_th) * $signed(sin_ph);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ux        <= 16'sd0;
            uy        <= 16'sd0;
            uz        <= 16'sd0;
            valid_out <= 1'b0;
        end else if (frame_start) begin
            ux        <= 16'sd0;
            uy        <= 16'sd0;
            uz        <= 16'sd0;
            valid_out <= 1'b0;
        end else if (enable) begin
            valid_out <= valid_th;
            if (valid_th) begin
                ux <= 16'((ux_full + 32'sd16384) >>> 15);
                uy <= 16'((uy_full + 32'sd16384) >>> 15);
                uz <= cos_th;
            end
        end
    end

endmodule
