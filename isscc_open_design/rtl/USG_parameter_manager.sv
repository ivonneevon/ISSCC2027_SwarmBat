module USG_parameter_manager
    import USG_parameter_pkg::*, USG_types::*;
(
    input  logic                     clk,
    input  logic                     rst_n,
    input  logic                     serial_in,
    input  logic                     serial_en,
    output logic                     serial_out,
    output logic                     done,
    output USG_Config_t              USG_PARAM
);

    localparam logic [RX_COORD_W-1:0] RX_COOR_ROM [0:31] = '{
        21'b000111000010111000001,
        21'b000111000100000000010,
        21'b000111000100111000011,
        21'b000111000101110000100,
        21'b000111000110011000101,
        21'b000111000111000000110,
        21'b000111000111101000111,
        21'b000111001000001001000,
        21'b000111001000101001001,
        21'b000111001001001001010,
        21'b000111001001101001011,
        21'b000111001010000001100,
        21'b000111001010011001101,
        21'b000111001010111001110,
        21'b000111001011010001111,
        21'b000111001011101010000,
        21'b000111001100000010001,
        21'b000111001100011010010,
        21'b000111001100110010011,
        21'b000111001101001010100,
        21'b000111001101011010101,
        21'b000111001101110010110,
        21'b000111001110001010111,
        21'b000111001110011011000,
        21'b000111001110110011001,
        21'b000111001111001011010,
        21'b000111001111011011011,
        21'b000111001111110011100,
        21'b000111010000000011101,
        21'b000111010000010011110,
        21'b000111010000101011111,
        21'b000111010000111100000
    };

    logic [N_CH_CFG*RX_COORD_W-1:0] RX_COOR_DEFAULT;
    genvar grx;
    generate
        for (grx = 0; grx < N_CH_CFG; grx++) begin : g_pack_rx
            assign RX_COOR_DEFAULT[grx*RX_COORD_W +: RX_COORD_W] = RX_COOR_ROM[grx];
        end
    endgenerate

    USG_Config_t USG_PARAM_DEFAULT;
    assign USG_PARAM_DEFAULT = '{

        dgd:   '{ ch_delay_flat: {32{8'd79}} },

        tpgt:  '{

            P_PHASE_CODE_UNIT_pulse_LF: 5'd20,
            P_PHASE_CODE_LF:            16'b0000_0100_1010_0100,
            P_NUM_pulse_LF:             9'd300,
            P_MID_clk_LF:               8'd48,
            P_PULSE_clk_LF:             12'd625,

            P_PHASE_CODE_UNIT_pulse_HF: 5'd1,
            P_PHASE_CODE_HF:            16'd0,
            P_NUM_pulse_HF:             9'd16,
            P_MID_clk_HF:               8'd48,
            P_PULSE_clk_HF:             12'd625
        },

        mmf:   '{ coef: 15'b000000100101001 },

        frame: '{
            FRAME_LENGTH: 15'd25500,
            CLK_DIVIDER:   7'd64
        },

        dg:    '{
            DG_CT_FS_OVER_C0:     16'd23324,
            DG_PSG_R_START_LF:    7'd35,

            DG_PSG_R_START_HF:    7'd30,

            DG_PSG_NUM_RADII:     7'd127,

            SC_DELTA_R_FINE_CF:   13'd5243,
            SC_DELTA_R_COARSE_CF: 17'd52429,
            SC_R_FINE_END_CF:     18'd131072,
            SC_DELTA_TH_CF:       13'd4289,
            SC_DELTA_PH_CF:       17'd102944,
            SC_DELTA_PH_FINE_CF:  22'd2516402,
            SC_PI_CF:             24'sd3294199,
            SC_TWO_PI_CF:         24'sd6588397,
            SC_R_BOUNDARY:        7'd25,

            rx_coor:              RX_COOR_DEFAULT
        },

        adcc:  '{ Delay_ADC_EN_clk: 10'd400 },

        ac:    '{
            Delay_Local_TX_clk:  7'd50,
            Delay_TX_cycle_LF:  12'd330,
            Delay_TX_cycle_HF:  12'd47,
            Delay_Sample_clk:    9'd250,
            Delay_RX_clk:        6'd25
        }
    };

    localparam int unsigned PARAM_BITS = $bits(USG_Config_t);

    USG_Config_t buffer1, buffer2;
    logic [$clog2(PARAM_BITS+1)-1:0] counter;

    always_ff @(posedge clk or negedge rst_n) begin: p_buffer1
        if (~rst_n)
            buffer1 <= USG_PARAM_DEFAULT;
        else if (serial_en)
            buffer1 <= {buffer1[PARAM_BITS-2:0], serial_in};
    end

    always_ff @(posedge clk or negedge rst_n) begin: p_buffer2
        if (~rst_n)
            buffer2 <= USG_PARAM_DEFAULT;
        else if (done)
            buffer2 <= buffer1;
    end

    always_ff @(posedge clk or negedge rst_n) begin: p_counter
        if (~rst_n)
            counter <= '0;
        else if (serial_en) begin
            if (counter < PARAM_BITS)
                counter <= counter + 1;
            else if (done)
                counter <= 1;
        end
    end

    assign done       = (counter == PARAM_BITS);
    assign serial_out = buffer1[PARAM_BITS-1];
    assign USG_PARAM  = buffer2;

endmodule
