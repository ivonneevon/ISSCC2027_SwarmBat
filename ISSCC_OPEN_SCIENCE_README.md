#Swarmbat - Single-Chip 3D Ultrasound Imaging 

Open-science artifacts accompanying the paper (paper number: **TODO**),
prepared for the ISSCC Open Science Badges.

| Folder | Badge | Contents |
|---|---|---|
| [`isscc_open_data/`](isscc_open_data/) | **Open Data** | The measured data points behind the paper's key imaging results: raw per-frame voxel outputs of the chip (CSV), with the decoding documentation and the script that regenerates the paper's figures. |
| [`isscc_open_design/`](isscc_open_design/) | **Open Design** | The ASIC RTL design source of the chip's digital backend (synthesizable SystemVerilog): transmit sequencing, ADC control, matched filtering, and 3D beamforming. Modules integrating third-party vendor IP are withheld per NDA and documented. |

Each folder is self-contained — see its own `README.md` for the data
format, decoding math, architecture overview, and build/run
instructions.

Per ISSCC Open Science Badge rules, this repository is frozen as of
October 1st and will remain available for at least three years.
