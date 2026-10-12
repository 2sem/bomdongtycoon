"""Tier-2 (jeonmun, 봄동 전문점) south-west wall: West -> South edge, camera-near like
`wall_shop_left`. One post at the South end (the corner it shares with the front wall).

Whitewashed plaster in a dark timber frame, a dark roof-tile eave and a
spring-green fascia. Tier 0/1 are 0.709 tall; HEIGHT 0.82 is part of the
silhouette step-up (judged at drawn size, brief range 0.78-0.88). Eave and
fascia heights below sit on top of / under that.

Geometry is expressed in (along, d, z): `along` runs along the edge, `d` is
distance from the grid edge toward the cell centre. The wall slab occupies
d in [0, THICKNESS]. Camera-near: the visible face is the un-offset side (d = 0).
"""

import isobuild
from isogrid import DIAMOND_VERTICES

CANVAS_UNITS = 2.0
LOOK_AT = (0.0, 0.5, 0.42)
OUTLINE_PX = 0.45

HEIGHT = 0.82
THICKNESS = 0.06
PLINTH_H = 0.09
FASCIA_H = 0.10
BEAM_H = 0.035
EAVE_H = 0.07
EAVE_OUT = 0.10     # overhang away from the cell centre
EAVE_IN = 0.03      # overhang past the slab's inner side
POST = 0.07
POST_PROUD = 0.01   # post end plane sits 0.01 off the end cap (else z-fights to black)
FRAME_PROUD = 0.012 # plinth / beam stand this far off the visible face
FASCIA_PROUD = 0.085   # near wall: the 0.10 outward eave hides a flush band, so the board stands proud to just inside the eave edge

EDGE_AXIS = "row"       # which grid coord is fixed along this edge
EDGE = 0.5           # its value
INWARD = -1           # sign of the cell-centre direction on that axis
FACE_D = 0.0    # d of the visible face
OUT = -1                 # d direction that is "proud of the visible face"


def _box(name, along, d, z, material):
    a0, a1 = along
    p0, p1 = EDGE + INWARD * d[0], EDGE + INWARD * d[1]
    lo, hi = min(p0, p1), max(p0, p1)
    if EDGE_AXIS == "col":
        center, width, depth = ((lo + hi) / 2, (a0 + a1) / 2), hi - lo, a1 - a0
    else:
        center, width, depth = ((a0 + a1) / 2, (lo + hi) / 2), a1 - a0, hi - lo
    isobuild.box(
        name, center=center, width=width, depth=depth, height=z[1] - z[0],
        face_material=material, trim_material=material, top_material=material,
        base_z=z[0],
    )


def _proud(amount):
    """d range standing `amount` off the visible face."""
    return (FACE_D, FACE_D + OUT * amount)


def build():
    plaster = isobuild.flat_material(
        "JeonmunPlaster", texture="plaster_wall.png", rgba=(0.89, 0.83, 0.72, 1.0)
    )
    timber = isobuild.flat_material(
        "JeonmunTimber", texture="timber_dark.png", rgba=(0.22, 0.15, 0.10, 1.0)
    )
    roof = isobuild.flat_material(
        "JeonmunRoof", texture="roof_tile.png", rgba=(0.29, 0.32, 0.36, 1.0)
    )
    green = isobuild.flat_material("JeonmunFascia", rgba=(0.36, 0.55, 0.27, 1.0))

    isobuild.wall(
        "JeonmunWallLeft",
        start=DIAMOND_VERTICES["west"],
        end=DIAMOND_VERTICES["south"],
        height=HEIGHT,
        thickness=THICKNESS,
        face_material=plaster,
        trim_material=timber,
        inward_toward=(0.0, 0.0),
        plank_count=1,
        texture_planks=0,
    )
    full = (-0.5, 0.5)
    _box("Plinth", full, _proud(FRAME_PROUD), (0.0, PLINTH_H), timber)
    fascia_z = (HEIGHT - FASCIA_H, HEIGHT)
    _box("Fascia", full, _proud(FASCIA_PROUD), fascia_z, green)
    _box("TieBeam", full, _proud(max(FRAME_PROUD + 0.01, FASCIA_PROUD)), (fascia_z[0] - BEAM_H, fascia_z[0]), timber)
    # Eave: the full cell edge so neighbouring cells read as one roofline.
    out_d = -EAVE_OUT if OUT < 0 else THICKNESS + EAVE_IN
    in_d = THICKNESS + EAVE_IN if OUT < 0 else -EAVE_OUT
    _box("Eave", full, (min(out_d, in_d), max(out_d, in_d)), (HEIGHT, HEIGHT + EAVE_H), roof)
    # Post ends stand POST_PROUD past the cell end, never coplanar with the cap.
    post_d = (FACE_D + OUT * POST_PROUD - OUT * POST, FACE_D + OUT * POST_PROUD)
    for name, along in [("PostS", (0.5 + POST_PROUD - POST, 0.5 + POST_PROUD))]:
        _box(name, along, post_d, (0.0, HEIGHT), timber)
    return {}
