module F_PSG
    import USG_parameter_pkg::*;
#(
    parameter logic [POSITION_THETA_WIDTH-1:0] TH_END  = 7'd127,
    parameter logic [POSITION_PHI_WIDTH-1:0]   PH_END  = 6'd63
) (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        frame_start,

    input  logic [POSITION_RADIUS_WIDTH-1:0]  R_START,
    input  logic [POSITION_RADIUS_WIDTH-1:0]  R_END,

    output logic [19:0] voxel_word,
    output logic        valid,
    input  logic        ready,
    output logic        done
);

    logic [POSITION_RADIUS_WIDTH-1:0] r_ctr;
    logic [POSITION_THETA_WIDTH-1:0]  th_ctr;
    logic [POSITION_PHI_WIDTH-1:0]    ph_ctr;
    logic                              running;
    logic                              done_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            running    <= 1'b0;
            done_reg   <= 1'b0;
            r_ctr      <= R_START;
            th_ctr     <= '0;
            ph_ctr     <= '0;
            voxel_word <= {R_START, 7'd0, 6'd0};
            valid      <= 1'b0;
            done       <= 1'b0;
        end else if (frame_start) begin
            running    <= 1'b0;
            done_reg   <= 1'b0;
            r_ctr      <= R_START;
            th_ctr     <= '0;
            ph_ctr     <= '0;
            voxel_word <= {R_START, 7'd0, 6'd0};
            valid      <= 1'b0;
            done       <= 1'b0;
        end else begin
            if (!running && !done_reg) begin
                running    <= 1'b1;
                voxel_word <= {r_ctr, th_ctr, ph_ctr};
                valid      <= 1'b1;
            end else if (running) begin
                if (ready) begin
                    if (ph_ctr == PH_END) begin
                        ph_ctr <= '0;
                        if (th_ctr == TH_END) begin
                            th_ctr <= '0;
                            if (r_ctr == R_END) begin
                                running    <= 1'b0;
                                valid      <= 1'b0;
                                done       <= 1'b1;
                                done_reg   <= 1'b1;
                            end else begin
                                r_ctr      <= r_ctr + 7'd1;
                                voxel_word <= {r_ctr + 7'd1, 7'd0, 6'd0};
                            end
                        end else begin
                            th_ctr     <= th_ctr + 7'd1;
                            voxel_word <= {r_ctr, th_ctr + 7'd1, 6'd0};
                        end
                    end else begin
                        ph_ctr     <= ph_ctr + 6'd1;
                        voxel_word <= {r_ctr, th_ctr, ph_ctr + 6'd1};
                    end
                end
            end
        end
    end

endmodule
