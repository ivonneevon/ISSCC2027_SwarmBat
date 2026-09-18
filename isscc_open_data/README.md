# Single-Chip 3D Ultrasound Imaging — Measured Data (ISSCC Open Data Badge)

This repository contains the measured data points behind the key
imaging results of the paper (paper number: **TODO**), together with
the script that renders the paper's figures from them.

The data are the direct output of the imaging chip: for each frame, a
list of above-threshold **voxels**, each an envelope magnitude and a
position on the chip's polar imaging grid. The script here only
decodes, calibrates, and plots them.

## Repository structure

```
README.md                     this file
data/
  scene1_20260907_232338/     measurement scene 1 (3 consecutive frames)
    f0_voxels.csv  f1_voxels.csv  f2_voxels.csv
  scene2_20260907_232714/     measurement scene 2 (3 consecutive frames)
    f0_voxels.csv  f1_voxels.csv  f2_voxels.csv
scripts/
  render_figures.py           renders the paper figures from a CSV
```

Each `f<N>_voxels.csv` is one complete frame, captured live from the
chip on 2026-09-07. The paper's figures use scene 1 frame 1 and
scene 2 frame 2; the neighboring frames are included to show
frame-to-frame consistency.

**Scene ground truth** (tape-measured reflector placements):

- Scene 1 (`scene1_20260907_232338`): **TODO — reflector types and
  measured positions**
- Scene 2 (`scene2_20260907_232714`): **TODO — reflector types and
  measured positions**

## Data format

CSV, one row per voxel, header row included:

| Column | Type | Meaning |
|---|---|---|
| `env_raw` | uint16 | Envelope magnitude (encoding below) |
| `pos_raw` | uint20 | Packed position `{r_idx[19:13], th_idx[12:6], ph_idx[5:0]}` |
| `r_idx` | 0..127 | Radial grid index (unpacked for convenience) |
| `th_idx` | 0..127 | Polar-angle index |
| `ph_idx` | 0..63 | Azimuth index |

Only voxels that exceeded the on-chip detection threshold are emitted.

### Envelope decoding (linear magnitude)

`env_raw` packs `{exp[15:11], mant[10:0]}`:

```
magnitude = (2048 + mant) * 2^(exp - 11)      for exp > 0
magnitude = mant                              for exp = 0
```

Values above 61439 are not producible by the encoder and are
discarded. Figures weight voxels by
`dB = 20*log10(magnitude / max_magnitude_in_frame)`.

### Position decoding (meters, degrees)

```
theta = th_idx * 0.2344 deg          (polar angle off boresight, 0..29.8 deg)
phi   = ph_idx * 5.625 deg + 180 deg (azimuth; wrap to (-180, 180])

r_decoded  = 0.225 + (r_idx - 45) * 0.05   [m]   (all indices in this
                                                  dataset are >= 45)
r_physical = 1.5 * r_decoded + 1.05        [m]
```

The last line is the calibrated range mapping for this measurement
configuration (verified against tape-measured targets); one radial bin
spans 7.5 cm of physical range. Cartesian coordinates:

```
x = r_physical * sin(theta) * cos(phi)    (lateral, m)
y = r_physical * sin(theta) * sin(phi)    (height, m)
z = r_physical * cos(theta)               (depth, m)
```

Field of view: a 30-degree-half-angle cone, ~1.4–7.0 m in depth.
Voxels below 1.3 m fall inside the transmit blind zone and are
excluded from figures.

## Regenerating the figures

Requires Python 3.9+ with `numpy`, `matplotlib`, `plotly`:

```
python scripts/render_figures.py data/scene1_20260907_232338 1
python scripts/render_figures.py data/scene2_20260907_232714 2
```

Each run writes, next to the CSV: the front-view and top-down PNGs, a
standalone depth colorbar PNG, and interactive 3D HTML renderings.
All decode and calibration constants above are implemented in
`load_frame()` in the script.

## Measurement conditions

In-air measurement, indoor lab; 40 kHz coded transmit, 32-element
receive array; frames captured live from the chip at ~15 frames/s.

## License

**TODO — choose before publishing** (suggested: CC-BY-4.0 for the
data, MIT for the script; state both here).

## Archival

**TODO — mint a DOI (e.g., Zenodo snapshot) and reference it here.**
This repository is frozen as of October 1st and will remain available
for at least three years, per ISSCC Open Science Badge rules.
