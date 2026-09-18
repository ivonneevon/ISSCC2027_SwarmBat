# Single-Chip 3D Ultrasound Imaging — ASIC RTL (ISSCC Open Design Badge)

This repository contains the **ASIC RTL design source** of the digital
backend behind the key results of the paper (paper number: **TODO**).
It is the synthesizable SystemVerilog of the fabricated chip's digital
backend: transmit sequencing, ADC control, matched filtering, and 3D
delay-and-sum beamforming, from the raw comparator inputs to the
thresholded voxel output (envelope + polar position).

## Repository structure

```
README.md            this file
rtl/
  filelist.f         compile-order file list (packages first)
  *.sv               29 SystemVerilog source files
```

Top-level module: **`F_USG10_core`**.

## Architecture overview

| Module group | Role |
|---|---|
| `USG_parameter_pkg` / `USG_types` / `USG_parameter_manager` | Design constants, configuration record types, and the runtime parameter image (serial upload interface, defaults, per-channel receive-element coordinate ROM) |
| `F_Frame_Trigger` | Frame-period generator and band (LF/HF) sequencing |
| `JY_*` | Analog-frontend controller: transmit pulse generation (coded burst), analog control sequencing, ADC controller/decoder |
| `F_ADC_Wrapper` | 32-channel ADC sample assembly |
| `SL_LO_Gen`, `SL_BPSK_Mixer`, `SL_MMF_*`, `SL_Correlator_TDM_SRAM`, `SL_Mixing_Match_Filter` | Per-channel mixing matched filter: LO generation, code correlation (time-multiplexed SRAM correlator), I/Q output |
| `F_PSG`, `F_SC_Mapper`, `F_SC_Mapper_RX`, `F_Cordic_*` (+ `F_DG_Channel`, `F_DG_Bank_polar` — withheld, see below) | Delay generator: polar scan sequencing (radius/theta/phi), index-to-coordinate mapping, CORDIC trigonometry, per-channel time-of-flight computation |
| `SL_Phase_Angle_Derive`, `SL_Phase_Rotator_LUT`, `SL_Sum_Up`, `SL_Envelope_Detector`, `SL_Beamformer` (+ `SL_Delay_Application_IQ` — withheld, see below) | Beamformer: per-channel delay application from I/Q history, phase rotation, coherent summation, envelope detection (pseudo-floating-point output), voxel output stream |

Voxel output format: a 20-bit position word
`{r_idx[19:13], th_idx[12:6], ph_idx[5:0]}` plus a 16-bit envelope
`{exp[15:11], mant[10:0]}`.

## Withheld modules (vendor-IP / NDA)

Four modules of the fabricated design directly integrate third-party
IP (EDA-vendor arithmetic components and technology-vendor SRAM
macros) and are **withheld from this release** to respect the
corresponding license and non-disclosure agreements:

- `F_DG_Channel` — per-channel time-of-flight computation
- `F_DG_Bank_polar` — delay-generator bank (instantiated by
  `F_USG10_core`)
- `SL_Correlator_TDM_SRAM` — correlator storage wrapper (instantiated
  by `SL_MMF_MatchedFilter`)
- `SL_Delay_Application_IQ` — I/Q history buffer and delay application
  (instantiated by `SL_Beamformer`)

The remaining sources reference these modules by name only. The
chip's IO pad ring (foundry pad cells) is likewise not included; this
release is the core-level design.

## Build

Any SystemVerilog-2012 tool. Compile in the order given by
`rtl/filelist.f` (the package files come first), e.g.:

```
vlog -sv -f rtl/filelist.f
```

The file set as provided compiles cleanly. Full elaboration of
`F_USG10_core` additionally requires the withheld modules listed
above.

## License

**TODO — choose before publishing** (e.g., Apache-2.0 with the
Solderpad hardware exception, or BSD-3-Clause; state it here and add a
LICENSE file).

## Archival

**TODO — mint a DOI (e.g., Zenodo snapshot) and reference it here.**
This repository is frozen as of October 1st and will remain available
for at least three years, per ISSCC Open Science Badge rules.
