module SL_Phase_Angle_Derive
    import USG_parameter_pkg::*, USG_types::*;
(
    input  logic [TOF_FULL_W-1:0]   tof,
    input  logic [12:0]             phase_inc,
    output logic [ANGLE_W-1:0]      angle
);

    logic [TOF_FULL_W+12:0]    product;
    logic [ANGLE_W-1:0]        angle_raw;

    assign product   = tof * phase_inc;

    assign angle_raw = product[TOF_FRAC_W +: ANGLE_W];

    assign angle     = -angle_raw;

endmodule
