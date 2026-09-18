`default_nettype wire

module SL_BPSK_Mixer
    import USG_parameter_pkg::*, USG_types::*;
(
    input  logic signed [BM_DATA_WIDTH-1:0] din,
    input  logic                            lo,

    output logic signed [BM_DATA_WIDTH-1:0] dout
);

    assign dout = lo ? din : -din;

endmodule

`default_nettype wire
