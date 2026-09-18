module SL_Sum_Up
    import USG_parameter_pkg::*, USG_types::*;
(
    input  logic                                                   clk,
    input  logic                                                   rst_n,
    input  logic                                                   frame_start,

    input  logic signed [N_CH-1:0][CORDIC_OUT_W-1:0]        up_data_i,
    input  logic signed [N_CH-1:0][CORDIC_OUT_W-1:0]        up_data_q,
    input  logic [POSITION_WIDTH-1:0]                              up_voxel_pos,
    input  logic                                                   up_valid,

    output logic [ENV_OUT_W-1:0]                                   down_intensity,
    output logic signed [ADDER_OUT_W-1:0]                          down_sum_i,
    output logic signed [ADDER_OUT_W-1:0]                          down_sum_q,
    output logic [POSITION_WIDTH-1:0]                              down_voxel_pos,
    output logic                                                   down_valid,
    input  logic                                                   down_ready
);

    logic signed [ADDER_OUT_W-1:0] sum_i_comb, sum_q_comb;

    always_comb begin
        sum_i_comb = '0;
        sum_q_comb = '0;
        for (int ch = 0; ch < N_CH; ch++) begin

            sum_i_comb = sum_i_comb + {{(ADDER_OUT_W-CORDIC_OUT_W){up_data_i[ch][CORDIC_OUT_W-1]}},
                                        up_data_i[ch]};
            sum_q_comb = sum_q_comb + {{(ADDER_OUT_W-CORDIC_OUT_W){up_data_q[ch][CORDIC_OUT_W-1]}},
                                        up_data_q[ch]};
        end
    end

    logic signed [ADDER_OUT_W-1:0] sum_i_reg, sum_q_reg;
    logic [POSITION_WIDTH-1:0]     pos_reg;
    logic                          sum_valid;

    logic env_ready;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sum_i_reg <= '0;
            sum_q_reg <= '0;
            pos_reg   <= '0;
            sum_valid <= 1'b0;
        end else if (frame_start) begin
            sum_i_reg <= '0;
            sum_q_reg <= '0;
            pos_reg   <= '0;
            sum_valid <= 1'b0;
        end else if (env_ready || !sum_valid) begin
            sum_i_reg <= sum_i_comb;
            sum_q_reg <= sum_q_comb;
            pos_reg   <= up_voxel_pos;
            sum_valid <= up_valid;
        end
    end

    assign down_sum_i = sum_i_reg;
    assign down_sum_q = sum_q_reg;

    SL_Envelope_Detector u_env (
        .clk         (clk),
        .rst_n       (rst_n),
        .frame_start (frame_start),
        .din_i       (sum_i_reg),
        .din_q       (sum_q_reg),
        .valid_in    (sum_valid),
        .ready_out   (env_ready),
        .dout        (down_intensity),
        .valid_out   (down_valid),
        .ready_in    (down_ready)
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            down_voxel_pos <= '0;
        end else if (frame_start) begin
            down_voxel_pos <= '0;
        end else if (env_ready || !down_valid) begin
            down_voxel_pos <= pos_reg;
        end
    end

endmodule
