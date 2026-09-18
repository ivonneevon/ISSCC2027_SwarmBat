#!/usr/bin/env python3
"""Render the paper figures from a measured voxel CSV (f<N>_voxels.csv).

Outputs, written next to the CSV:
    f<N>_front.png       Front View (Azimuth / Elevation)
    f<N>_top.png         Top-Down View (Radius)
    f<N>_colorbar.png    standalone shared Depth [m] colorbar
    f<N>_3d_*.html       interactive 3D renderings (spherical grid,
                         no-grid, and optional dot/thick grid styles)

Flags:
    --dotgrid    also write a 3D version with a dotted grid
    --thickgrid  also write a 3D version with a heavier solid grid

Usage:
    python scripts/render_figures.py data/<scene_dir> <frame#>

Requires: numpy, matplotlib, plotly.
"""
import sys
from pathlib import Path

import numpy as np

# ---- decode & display constants (documented in README.md) ----------
R_BOUNDARY = 45              # radial index where the grid step changes
FINE_END_M = 0.225           # decoded range at index 45 [m]
COARSE_M = 0.05              # radial step for index >= 45 [m]
FINE_M = 0.005               # radial step for index < 45 [m] (unused
                             # by the scan range in this dataset)
TH_STEP_DEG = 0.2343581      # polar-angle grid step [deg]
PH_STEP_DEG = 5.625          # azimuth grid step [deg]
R_CAL_SCALE = 1.5            # calibrated range mapping:
R_CAL_OFFSET_M = 1.05        #   r_physical = 1.5 * r_decoded + 1.05 m
VIEW_DEG = 30.0              # field-of-view half angle [deg]
VIEW_R_MAX = 7.0             # displayed depth extent [m]
VIEW_R_MIN = 1.3             # blind-zone cutoff [m]
ENV_MAX = 61439              # largest legal envelope encoding
DB_FLOOR = -30.0             # alpha fade floor [dB]
TOP_N = 4000                 # keep at most this many brightest voxels


def load_frame(csv_path):
    rows = np.loadtxt(csv_path, delimiter=',', skiprows=1, dtype=np.int64)
    env, r_idx, th_idx, ph_idx = rows[:, 0], rows[:, 2], rows[:, 3], rows[:, 4]
    keep = (env != 0) & (env <= ENV_MAX)
    env, r_idx, th_idx, ph_idx = env[keep], r_idx[keep], th_idx[keep], ph_idx[keep]

    # envelope: pseudo-floating-point {exp[15:11], mant[10:0]} -> linear
    # magnitude -> dB relative to the frame maximum
    exp_e = (env >> 11) & 0x1F
    mant = env & 0x7FF
    mag = np.where(exp_e > 0, mant + 2048, mant) * np.power(2.0, exp_e - 11.0)
    db = 20.0 * np.log10(np.maximum(mag, 1e-12) / max(mag.max(), 1e-12))

    # polar grid indices -> physical coordinates (see README.md)
    r_dec = np.where(r_idx < R_BOUNDARY, r_idx * FINE_M,
                     FINE_END_M + (r_idx - R_BOUNDARY) * COARSE_M)
    th = np.radians(th_idx * TH_STEP_DEG)
    # azimuth reference: +180 deg, wrapped to (-pi, pi]
    ph = np.radians(ph_idx * PH_STEP_DEG + 180.0)
    ph = np.where(ph > np.pi, ph - 2 * np.pi, ph)
    r_phys = r_dec * R_CAL_SCALE + R_CAL_OFFSET_M
    x = r_phys * np.sin(th) * np.cos(ph)
    y = r_phys * np.sin(th) * np.sin(ph)
    z = r_phys * np.cos(th)

    keep = (r_phys >= VIEW_R_MIN) & (r_phys <= VIEW_R_MAX)
    x, y, z, r_phys, db = x[keep], y[keep], z[keep], r_phys[keep], db[keep]
    if x.size > TOP_N:
        k = np.argsort(db)[-TOP_N:]
        x, y, z, r_phys, db = x[k], y[k], z[k], r_phys[k], db[k]
    return x, y, z, r_phys, db


def colors_alpha(r, db):
    """RGB = red (near) -> blue (far) over 0..VIEW_R_MAX; alpha = dB."""
    f = np.clip(r / VIEW_R_MAX, 0.0, 1.0)
    a = (70 + 185 * np.clip((db - DB_FLOOR) / -DB_FLOOR, 0.0, 1.0)) / 255.0
    return np.stack([1 - f, np.zeros_like(f), f, a], axis=-1)


# ---- 2D views (matplotlib) ------------------------------------------
def render_2d(x, y, z, r, db, out_front, out_top, out_cbar):
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    plt.rcParams.update({'font.family': 'Arial', 'font.weight': 'bold',
                         'font.size': 13})
    rgba = colors_alpha(r, db)

    # Front view: azimuth/elevation in degrees, 10/20 deg dashed
    # circles, solid 30 deg boundary ring
    fig, ax = plt.subplots(figsize=(5.2, 5.2), dpi=150)
    ax.set_aspect('equal')
    tt = np.linspace(0, 2 * np.pi, 181)
    for ring in (10, 20):
        ax.plot(ring * np.cos(tt), ring * np.sin(tt), ls=(0, (5, 4)),
                lw=1.6, color='#999999', zorder=1)
    ax.plot(30 * np.cos(tt), 30 * np.sin(tt), lw=3.2, color='#111111',
            zorder=2)
    ax.plot([0], [0], 'o', ms=6, color='#111111', zorder=3)
    az = np.degrees(np.arctan2(x, z))
    el = np.degrees(np.arctan2(y, z))
    ax.scatter(az, el, s=8, c=rgba, linewidths=0, zorder=4)
    for ring in (10, 20):
        ax.text(ring * 0.7071 + 0.7, ring * 0.7071 + 0.7, f'{ring}\N{DEGREE SIGN}',
                fontsize=11, fontweight='bold', color='#666666')
    ax.text(30 * 0.7071 + 0.7, 30 * 0.7071 + 0.7, '30\N{DEGREE SIGN}',
            fontsize=12, fontweight='bold', color='#111111')
    ax.set_xlim(-33, 33); ax.set_ylim(-33, 33)
    ax.axis('off')
    ax.set_title('Front View (Azimuth / Elevation)', fontsize=14,
                 fontweight='bold', color='#111111', pad=12)
    fig.tight_layout()
    fig.savefig(out_front, facecolor='white')
    plt.close(fig)

    # Top-down view: field-of-view wedge with range arcs
    fig, ax = plt.subplots(figsize=(5.2, 5.6), dpi=150)
    ax.set_aspect('equal')
    s30, c30 = np.sin(np.radians(VIEW_DEG)), np.cos(np.radians(VIEW_DEG))
    arc = np.linspace(-np.radians(VIEW_DEG), np.radians(VIEW_DEG), 121)
    ax.plot([0, VIEW_R_MAX * s30], [0, VIEW_R_MAX * c30], lw=3.2,
            color='#111111', zorder=2)
    ax.plot([0, -VIEW_R_MAX * s30], [0, VIEW_R_MAX * c30], lw=3.2,
            color='#111111', zorder=2)
    ax.plot(VIEW_R_MAX * np.sin(arc), VIEW_R_MAX * np.cos(arc), lw=3.2,
            color='#111111', zorder=2)
    for rm in range(1, int(VIEW_R_MAX)):
        ax.plot(rm * np.sin(arc), rm * np.cos(arc), ls=(0, (5, 4)), lw=1.6,
                color='#999999', zorder=1)
        ax.text(rm * s30 + 0.07, rm * c30, f'{rm} m', fontsize=11,
                fontweight='bold', color='#111111', va='center')
    ax.text(VIEW_R_MAX * s30 + 0.07, VIEW_R_MAX * c30,
            f'{VIEW_R_MAX:.0f} m', fontsize=12, fontweight='bold',
            color='#111111', va='center')
    ax.plot([0], [0], 'o', ms=7, color='#111111', zorder=3)
    ax.scatter(x, z, s=8, c=rgba, linewidths=0, zorder=4)
    ax.set_xlim(-VIEW_R_MAX / 2 - 0.3, VIEW_R_MAX / 2 + 0.9)
    ax.set_ylim(-0.25, VIEW_R_MAX + 0.35)
    ax.axis('off')
    ax.set_title('Top-Down View (Radius)', fontsize=14, fontweight='bold',
                 color='#111111', pad=12)
    fig.tight_layout()
    fig.savefig(out_top, facecolor='white')
    plt.close(fig)

    # Standalone shared colorbar
    fig, ax = plt.subplots(figsize=(1.15, 5.2), dpi=150)
    grad = np.zeros((256, 1, 3))
    fr = np.linspace(0, 1, 256)[:, None]
    grad[:, :, 0] = 1 - fr
    grad[:, :, 2] = fr
    ax.imshow(grad, origin='lower', aspect='auto',
              extent=[0, 1, 0, VIEW_R_MAX])
    ax.set_xticks([])
    ax.set_yticks(range(0, int(VIEW_R_MAX) + 1))
    ax.tick_params(labelsize=13, width=1.6)
    ax.set_ylabel('Depth [m]', fontsize=15, fontweight='bold')
    for sp in ax.spines.values():
        sp.set_linewidth(1.6)
    fig.tight_layout()
    fig.savefig(out_cbar, facecolor='white')
    plt.close(fig)


# ---- 3D view (plotly) -----------------------------------------------
BOLD = 'Arial'               # labels/titles: Arial + <b> tags
TICK = 'Arial Black'         # tick numbers cannot take <b> tags, so
                             # the Black face supplies their bold

def render_3d(x, y, z, r, db, out_html, grid=True, dot=False,
              grid_width=2):
    import plotly.graph_objects as go
    s30, c30 = np.sin(np.radians(VIEW_DEG)), np.cos(np.radians(VIEW_DEG))
    # scene mapping: plotly-x = lateral x, plotly-y = height y,
    # plotly-z = depth z (vertical axis -> the cone opens upward)
    traces = [go.Scatter3d(
        x=x, y=y, z=z,
        mode='markers',
        marker=dict(size=3, color=r, cmin=0.0, cmax=VIEW_R_MAX,
                    colorscale=[[0.0, 'red'], [1.0, 'blue']],
                    colorbar=dict(title=dict(text='<b>Depth [m]</b>',
                                             font=dict(family=BOLD,
                                                       size=28,
                                                       color='#000000')),
                                  tickfont=dict(family=TICK, size=22,
                                                color='#000000'),
                                  x=0.78, xanchor='left',
                                  len=0.72, thickness=26),
                    opacity=0.85),
        text=[f'{v:.1f} dB' for v in db], name='voxels')]

    # grid style: thin solid lines, or uniformly spaced dots (plotly
    # 3D lines have no dash support)
    DOT_STEP = 0.3               # meters of arc between grid dots
    def _n_dots(length_m):
        return max(8, int(round(length_m / DOT_STEP)))
    if dot:
        thin = dict(mode='markers',
                    marker=dict(size=2.0, color='#d4d4d4'),
                    hoverinfo='skip', showlegend=False)
    else:
        thin = dict(mode='lines',
                    line=dict(color='#bbbbbb', width=grid_width),
                    hoverinfo='skip', showlegend=False)
    tt = np.linspace(0, 2 * np.pi, 73)
    ta = np.linspace(-np.radians(VIEW_DEG), np.radians(VIEW_DEG), 61)

    if grid:
        # spherical grid: every 1 m shell carries theta rings at
        # 10/20/30 deg plus two meridian arcs; 8 cone generatrices
        labels_x, labels_z, labels_t = [], [], []
        for rm in range(1, int(VIEW_R_MAX) + 1):
            for thdeg in (10.0, 20.0, 30.0):
                st, ct = (np.sin(np.radians(thdeg)),
                          np.cos(np.radians(thdeg)))
                tr = (np.linspace(0, 2 * np.pi,
                                  _n_dots(2 * np.pi * rm * st),
                                  endpoint=False) if dot else tt)
                traces.append(go.Scatter3d(
                    x=rm * st * np.cos(tr), y=rm * st * np.sin(tr),
                    z=np.full(tr.size, rm * ct), **thin))
            tm = (np.linspace(-np.radians(VIEW_DEG), np.radians(VIEW_DEG),
                              _n_dots(rm * 2 * np.radians(VIEW_DEG)))
                  if dot else ta)
            traces.append(go.Scatter3d(
                x=rm * np.sin(tm), y=np.zeros(tm.size),
                z=rm * np.cos(tm), **thin))
            traces.append(go.Scatter3d(
                x=np.zeros(tm.size), y=rm * np.sin(tm),
                z=rm * np.cos(tm), **thin))
            labels_x.append(rm * s30 * 1.08)
            labels_z.append(rm * c30)
            labels_t.append(f'<b>{rm} m</b>')
        traces.append(go.Scatter3d(
            x=labels_x, y=np.zeros(len(labels_x)), z=labels_z,
            mode='text', text=labels_t,
            textfont=dict(family=BOLD, size=22, color='#000000'),
            hoverinfo='skip', showlegend=False))
        gen_t = np.linspace(0.0, 1.0, _n_dots(VIEW_R_MAX) if dot else 2)
        for p in np.linspace(0, 2 * np.pi, 8, endpoint=False):
            traces.append(go.Scatter3d(
                x=gen_t * VIEW_R_MAX * s30 * np.cos(p),
                y=gen_t * VIEW_R_MAX * s30 * np.sin(p),
                z=gen_t * VIEW_R_MAX * c30, **thin))

    # xyz direction triad on the floor corner (away from the data)
    AX0, AY0, AZ0 = -3.0, -3.0, 0.0
    ALEN = 0.85
    for dx, dy, dz, lbl in ((ALEN, 0, 0, 'x'),
                            (0, ALEN, 0, 'y'),
                            (0, 0, ALEN, 'z')):
        traces.append(go.Scatter3d(
            x=[AX0, AX0 + dx], y=[AY0, AY0 + dy], z=[AZ0, AZ0 + dz],
            mode='lines', line=dict(color='#111111', width=6),
            hoverinfo='skip', showlegend=False))
        traces.append(go.Cone(
            x=[AX0 + dx], y=[AY0 + dy], z=[AZ0 + dz],
            u=[dx], v=[dy], w=[dz],
            sizemode='absolute', sizeref=0.2, anchor='tip',
            colorscale=[[0, '#111111'], [1, '#111111']],
            showscale=False, hoverinfo='skip'))
        traces.append(go.Scatter3d(
            x=[AX0 + dx * 1.35], y=[AY0 + dy * 1.35], z=[AZ0 + dz * 1.3],
            mode='text', text=[f'<b>{lbl}</b>'],
            textfont=dict(family=BOLD, size=34, color='#000000'),
            hoverinfo='skip', showlegend=False))

    lat = VIEW_R_MAX * s30 + 0.1
    dep = VIEW_R_MAX + 0.1
    _ax = dict(title_font=dict(family=BOLD, size=26, color='#000000'),
               tickfont=dict(family=TICK, size=19, color='#000000'))
    # camera presets; 'orbit' dragmode allows free rotation to any
    # angle (the default turntable mode locks the vertical axis)
    _up_z = dict(x=0, y=0, z=1)
    _cams = [
        ('Isometric', dict(eye=dict(x=0.35, y=1.9, z=0.75), up=_up_z)),
        ('Front',     dict(eye=dict(x=0.0, y=0.0, z=-2.3),
                           up=dict(x=0, y=1, z=0))),
        ('Top-Down',  dict(eye=dict(x=0.0, y=2.4, z=0.02), up=_up_z)),
        ('Side',      dict(eye=dict(x=2.4, y=0.1, z=0.15), up=_up_z)),
    ]
    fig = go.Figure(data=traces)
    fig.update_layout(
        scene=dict(
            # x range reversed (imaging display convention): in the
            # Front view (+z into the screen, +y up) +x points
            # screen-right, matching the 2D views
            xaxis=dict(title='<b>x lateral [m]</b>', range=[lat, -lat], **_ax),
            yaxis=dict(title='<b>y height [m]</b>', range=[-lat, lat], **_ax),
            zaxis=dict(title='<b>z depth [m]</b>', range=[0.0, dep], **_ax),
            aspectmode='manual',
            aspectratio=dict(x=1.0, y=1.0, z=dep / (2 * lat)),
            dragmode='orbit',
            camera=_cams[0][1]),
        updatemenus=[dict(
            type='buttons', direction='right', x=0.0, y=1.06,
            xanchor='left', yanchor='top', showactive=True,
            font=dict(family=TICK, size=18, color='#000000'),
            buttons=[dict(label=nm, method='relayout',
                          args=[{'scene.camera': cam}])
                     for nm, cam in _cams])],
        font=dict(family='Arial', size=18, color='#000000'),
        template='plotly_white', margin=dict(l=0, r=0, t=60, b=0))
    fig.write_html(str(out_html))


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    cap_dir = Path(args[0])
    fi = int(args[1]) if len(args) > 1 else 0
    csv = cap_dir / f'f{fi}_voxels.csv'
    x, y, z, r, db = load_frame(csv)
    tag = ''
    render_2d(x, y, z, r, db,
              cap_dir / f'f{fi}_front{tag}.png',
              cap_dir / f'f{fi}_top{tag}.png',
              cap_dir / f'f{fi}_colorbar.png')
    render_3d(x, y, z, r, db, cap_dir / f'f{fi}_3d_spherical{tag}.html',
              grid=True)
    render_3d(x, y, z, r, db, cap_dir / f'f{fi}_3d_nogrid{tag}.html',
              grid=False)
    if '--dotgrid' in sys.argv:
        render_3d(x, y, z, r, db,
                  cap_dir / f'f{fi}_3d_dotgrid{tag}.html',
                  grid=True, dot=True)
    if '--thickgrid' in sys.argv:
        render_3d(x, y, z, r, db,
                  cap_dir / f'f{fi}_3d_thickgrid{tag}.html',
                  grid=True, dot=False, grid_width=4)
    print(f'{x.size} voxels rendered')
    for lo, hi in [(VIEW_R_MIN, 3.0), (3.0, 4.5), (4.5, VIEW_R_MAX)]:
        k = (r >= lo) & (r < hi)
        if k.any():
            print(f'  depth {lo:.1f}-{hi:.1f} m: {k.sum():5d} voxels, '
                  f'centroid x={x[k].mean():+.2f} m, z={z[k].mean():.2f} m')


if __name__ == '__main__':
    main()
