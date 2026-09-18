`default_nettype wire

module F_ADC_Wrapper
    import USG_parameter_pkg::*, USG_types::*;
(
    input  logic                                   clk,
    input  logic                                   rst_n,
    input  logic                                   frame_start,

    input  logic [N_CH_CFG/4-1:0]                       adc_lf_cmp_out,
    input  logic                                        adc_lf_ch1_index,

    input  logic [N_CH_CFG/4-1:0]                       adc_hf_cmp_out,
    input  logic                                        adc_hf_ch1_index,

    input  logic                                   adc_ext_dir,
    input  logic                                   mode_HF_en,
    input  logic [31:0]                            adc_data_32ch_ext,
    input  logic                                   adc_valid_ext,
    output logic [31:0]                            adc_data_32ch_out,

    output logic                                   valid_out,
    output logic [N_CH_ALL-1:0][ADC_WIDTH-1:0]         data_out
);

    logic [ADCW_N_SLICE_LF-1:0] cmp_active;
    logic                       ch1_active;

    assign cmp_active = mode_HF_en ? adc_hf_cmp_out[ADCW_N_SLICE_HF-1:0]
                                   : adc_lf_cmp_out[ADCW_N_SLICE_LF-1:0];
    assign ch1_active = mode_HF_en ? adc_hf_ch1_index : adc_lf_ch1_index;

    logic [ADCW_N_SLICE_LF-1:0] adcd_valid;
    logic [ADCW_N_SLICE_LF-1:0] adcd_ser1;
    logic [ADCW_N_SLICE_LF-1:0] adcd_ser2;
    logic [ADCW_N_SLICE_LF-1:0] adcd_ser3;
    logic [ADCW_N_SLICE_LF-1:0] adcd_ser4;

    genvar s;
    generate
        for (s = 0; s < ADCW_N_SLICE_LF; s++) begin : g_adcdi
            JY_ADCD u_ADCDI (
                .clk         (clk),
                .rst_n       (rst_n),
                .cmp_out     (cmp_active[s]),
                .ch1_index   (ch1_active),
                .frame_start (frame_start),
                .ADCD_valid  (adcd_valid[s]),
                .ADCD_ser1   (adcd_ser1[s]),
                .ADCD_ser2   (adcd_ser2[s]),
                .ADCD_ser3   (adcd_ser3[s]),
                .ADCD_ser4   (adcd_ser4[s])
            );
        end
    endgenerate

    logic [ADCW_N_SLICE_LF-1:0] ext_ser1, ext_ser2, ext_ser3, ext_ser4;
    generate
        for (s = 0; s < ADCW_N_SLICE_LF; s++) begin : g_pack_ext
            assign ext_ser1[s] = adc_data_32ch_ext[4*s + 0];
            assign ext_ser2[s] = adc_data_32ch_ext[4*s + 1];
            assign ext_ser3[s] = adc_data_32ch_ext[4*s + 2];
            assign ext_ser4[s] = adc_data_32ch_ext[4*s + 3];
        end
    endgenerate

    logic [ADCW_N_SLICE_LF-1:0] mux_ser1, mux_ser2, mux_ser3, mux_ser4;
    logic                       mux_trigger;

    always_comb begin
        if (adc_ext_dir) begin
            mux_ser1    = ext_ser1;
            mux_ser2    = ext_ser2;
            mux_ser3    = ext_ser3;
            mux_ser4    = ext_ser4;
            mux_trigger = adc_valid_ext;
        end else begin
            mux_ser1    = adcd_ser1;
            mux_ser2    = adcd_ser2;
            mux_ser3    = adcd_ser3;
            mux_ser4    = adcd_ser4;
            mux_trigger = |adcd_valid;
        end
    end

    logic [31:0] obs_active;
    generate
        for (s = 0; s < ADCW_N_SLICE_LF; s++) begin : g_obs_pack
            assign obs_active[4*s + 0] = mux_ser1[s];
            assign obs_active[4*s + 1] = mux_ser2[s];
            assign obs_active[4*s + 2] = mux_ser3[s];
            assign obs_active[4*s + 3] = mux_ser4[s];
        end
    endgenerate
    assign adc_data_32ch_out = obs_active;

    logic                 capturing;
    logic [3:0]           cap_cnt;
    logic                 parallel_valid;
    logic [ADC_WIDTH-1:0] shift_reg [0:ADCW_N_SLICE_LF-1][0:3];

    wire trigger = mux_trigger;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            capturing      <= 1'b0;
            cap_cnt        <= 4'd0;
            parallel_valid <= 1'b0;
            for (int i = 0; i < ADCW_N_SLICE_LF; i++) begin
                shift_reg[i][0] <= '0;
                shift_reg[i][1] <= '0;
                shift_reg[i][2] <= '0;
                shift_reg[i][3] <= '0;
            end
        end else if (frame_start) begin
            capturing      <= 1'b0;
            cap_cnt        <= 4'd0;
            parallel_valid <= 1'b0;
            for (int i = 0; i < ADCW_N_SLICE_LF; i++) begin
                shift_reg[i][0] <= '0;
                shift_reg[i][1] <= '0;
                shift_reg[i][2] <= '0;
                shift_reg[i][3] <= '0;
            end
        end else begin
            parallel_valid <= 1'b0;

            if (!capturing) begin
                if (trigger) begin

                    for (int i = 0; i < ADCW_N_SLICE_LF; i++) begin
                        shift_reg[i][0] <= {{(ADC_WIDTH-1){1'b0}}, mux_ser1[i]};
                        shift_reg[i][1] <= {{(ADC_WIDTH-1){1'b0}}, mux_ser2[i]};
                        shift_reg[i][2] <= {{(ADC_WIDTH-1){1'b0}}, mux_ser3[i]};
                        shift_reg[i][3] <= {{(ADC_WIDTH-1){1'b0}}, mux_ser4[i]};
                    end
                    cap_cnt   <= 4'd1;
                    capturing <= 1'b1;
                end
            end else begin

                for (int i = 0; i < ADCW_N_SLICE_LF; i++) begin
                    shift_reg[i][0] <= {shift_reg[i][0][ADC_WIDTH-2:0], mux_ser1[i]};
                    shift_reg[i][1] <= {shift_reg[i][1][ADC_WIDTH-2:0], mux_ser2[i]};
                    shift_reg[i][2] <= {shift_reg[i][2][ADC_WIDTH-2:0], mux_ser3[i]};
                    shift_reg[i][3] <= {shift_reg[i][3][ADC_WIDTH-2:0], mux_ser4[i]};
                end

                if (cap_cnt == 4'd9) begin

                    capturing      <= 1'b0;
                    cap_cnt        <= 4'd0;
                    parallel_valid <= 1'b1;
                end else begin
                    cap_cnt <= cap_cnt + 4'd1;
                end
            end
        end
    end

    generate
        for (s = 0; s < ADCW_N_SLICE_LF; s++) begin : g_flatten
            assign data_out[4*s + 0]            = mode_HF_en ? '0 : shift_reg[s][0];
            assign data_out[4*s + 1]            = mode_HF_en ? '0 : shift_reg[s][1];
            assign data_out[4*s + 2]            = mode_HF_en ? '0 : shift_reg[s][2];
            assign data_out[4*s + 3]            = mode_HF_en ? '0 : shift_reg[s][3];
            assign data_out[N_CH_LF + 4*s + 0]  = mode_HF_en ? shift_reg[s][0] : '0;
            assign data_out[N_CH_LF + 4*s + 1]  = mode_HF_en ? shift_reg[s][1] : '0;
            assign data_out[N_CH_LF + 4*s + 2]  = mode_HF_en ? shift_reg[s][2] : '0;
            assign data_out[N_CH_LF + 4*s + 3]  = mode_HF_en ? shift_reg[s][3] : '0;
        end
    endgenerate

    assign valid_out = parallel_valid;

endmodule

`default_nettype wire
