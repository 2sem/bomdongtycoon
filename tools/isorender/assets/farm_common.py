"""Shared builder for the farm plot stages. One grid cell footprint (bed
0.84 x 0.84 inside the 1.0 diamond, so neighbouring plots keep a lane).
Stage is told by shape, not only colour: bare furrows -> thin stalks ->
leafy bushes -> fat pale heads plus a gold harvest flag; plot_add is a pale
unfilled bed with a raised gold "+".
"""
import isobuild

BED = 0.84
TIMBER = (0.52, 0.33, 0.17, 1.0)
SOIL = (0.30, 0.19, 0.11, 1.0)
FURROW = (0.22, 0.14, 0.08, 1.0)
LEAF = (0.22, 0.46, 0.14, 1.0)
LEAF_LIGHT = (0.38, 0.62, 0.20, 1.0)
HEAD = (0.55, 0.72, 0.30, 1.0)
GOLD = (0.90, 0.64, 0.08, 1.0)


def mat(n, rgba):
    return isobuild.flat_material(n, texture=None, rgba=rgba)


def box(n, c, w, d, h, z0, m):
    isobuild.box(n, center=c, width=w, depth=d, height=h, face_material=m,
                 trim_material=m, top_material=m, base_z=z0)


def frame(timber_m, h=0.09, t=0.07):
    half = BED / 2 - t / 2
    box("FrameN", (0.0, -half), BED, t, h, 0.0, timber_m)
    box("FrameS", (0.0, half), BED, t, h, 0.0, timber_m)
    box("FrameW", (-half, 0.0), t, BED - 2 * t, h, 0.0, timber_m)
    box("FrameE", (half, 0.0), t, BED - 2 * t, h, 0.0, timber_m)


def bed():
    frame(mat("Frame", TIMBER))
    inner = BED - 0.14
    box("Soil", (0.0, 0.0), inner, inner, 0.06, 0.0, mat("Soil", SOIL))
    furrow = mat("Furrow", FURROW)
    for i, r in enumerate((-0.20, 0.0, 0.20)):
        box(f"Furrow{i}", (0.0, r), inner - 0.06, 0.07, 0.025, 0.06, furrow)


def plants(n_cols, stalk_h, leaf, leaf_h, stalk_w=0.04):
    sm, tm = mat("Stalk", LEAF), mat("Leaf", LEAF_LIGHT)
    cols = [(-0.22 + 0.22 * i) for i in range(n_cols)]
    if n_cols == 2:
        cols = [-0.11, 0.11]
    for r_i, r in enumerate((-0.20, 0.0, 0.20)):
        for c_i, c in enumerate(cols):
            box(f"S{r_i}{c_i}", (c, r), stalk_w, stalk_w, stalk_h, 0.085, sm)
            box(f"L{r_i}{c_i}", (c, r), leaf, leaf, leaf_h, 0.085 + stalk_h, tm)
    return 0.085 + stalk_h + leaf_h


def markers(top):
    h = BED / 2
    return {"base_center": (0.0, 0.0, 0.0), "top_center": (0.0, 0.0, top),
            "base_corner_north": (-h, -h, 0.0), "base_corner_east": (h, -h, 0.0),
            "base_corner_south": (h, h, 0.0), "base_corner_west": (-h, h, 0.0)}
