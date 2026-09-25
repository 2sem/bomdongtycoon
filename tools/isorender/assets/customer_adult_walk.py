"""Pilot customer figure — mid-stride walk pose, same body plan and colours
as `customer_adult_idle.py`; see that module's docstring for the shared
reasoning (six-box peg-doll minifig, no rig change, sizing against the cash
counter). This module differs only in the legs: one slab replaced by two,
staggered along the row axis.

Stride splits along row, not col, because that's the customer's line of
travel in this scene — road at map row 10, counter around row 0-1, straight
down the row axis at a fixed col. No face is painted, so the same silhouette
reads walking either direction along that line; no mirrored/reversed variant
is needed for this pilot.

Torso/arms/head/hair are copied verbatim from the idle pose's numbers
(unchanged), not re-derived, so the two poses stay visually identical above
the hip — the only thing that should differ between an idle and a walk frame
of the same figure.

Revision note (post-pilot-review): carries the same hair-top and arm-width
fixes as `customer_adult_idle.py` — see that module's docstring for why.
Both poses take the fix identically since torso/arms/head/hair are shared.
"""

import isobuild

CANVAS_UNITS = 1.2
LOOK_AT = (0.0, 0.0, 0.30)
OUTLINE_PX = 0.45

SKIN_RGBA = (0.85, 0.68, 0.53, 1.0)
HAIR_RGBA = (0.25, 0.16, 0.10, 1.0)
SHIRT_RGBA = (0.30, 0.45, 0.50, 1.0)
PANTS_RGBA = (0.32, 0.27, 0.24, 1.0)  # target mean ~RGB(82,69,61), warm
                                       # brown-grey — see idle module's
                                       # docstring for why

LEG_WIDTH = 0.05
LEG_DEPTH = 0.07
LEG_HEIGHT = 0.24
LEG_Z0 = 0.0
LEG_ROW_OFFSET = 0.06
LEG_FORWARD_CENTER = (0.0, LEG_ROW_OFFSET)
LEG_BACK_CENTER = (0.0, -LEG_ROW_OFFSET)

TORSO_CENTER = (0.0, 0.0)
TORSO_WIDTH = 0.16
TORSO_DEPTH = 0.10
TORSO_HEIGHT = 0.18
TORSO_Z0 = 0.24

ARM_WIDTH = 0.07   # was 0.05
ARM_DEPTH = 0.12   # was 0.09 — deeper than the torso's own 0.10
ARM_HEIGHT = 0.16
ARM_Z0 = 0.25
ARM_OFFSET_COL = 0.115  # torso half-width 0.08 + new arm half-width 0.035
LEFT_ARM_CENTER = (-ARM_OFFSET_COL, 0.0)
RIGHT_ARM_CENTER = (ARM_OFFSET_COL, 0.0)

HEAD_CENTER = (0.0, 0.0)
HEAD_WIDTH = 0.14
HEAD_DEPTH = 0.12
HEAD_HEIGHT = 0.18
HEAD_Z0 = 0.42

HAIR_CENTER = (0.0, 0.0)
HAIR_WIDTH = 0.15
HAIR_DEPTH = 0.13
HAIR_HEIGHT = 0.08  # was 0.06
HAIR_Z0 = 0.53       # was 0.54 — z1 = 0.61, above HEAD's own z1 = 0.60

TOTAL_HEIGHT = HAIR_Z0 + HAIR_HEIGHT  # 0.61


def build():
    skin = isobuild.flat_material("CustomerSkin", texture=None, rgba=SKIN_RGBA)
    hair = isobuild.flat_material("CustomerHair", texture=None, rgba=HAIR_RGBA)
    shirt = isobuild.flat_material("CustomerShirt", texture=None, rgba=SHIRT_RGBA)
    pants = isobuild.flat_material("CustomerPants", texture=None, rgba=PANTS_RGBA)

    isobuild.box(
        "CustomerAdultLegForward",
        center=LEG_FORWARD_CENTER,
        width=LEG_WIDTH,
        depth=LEG_DEPTH,
        height=LEG_HEIGHT,
        face_material=pants,
        trim_material=pants,
        top_material=pants,
        base_z=LEG_Z0,
    )
    isobuild.box(
        "CustomerAdultLegBack",
        center=LEG_BACK_CENTER,
        width=LEG_WIDTH,
        depth=LEG_DEPTH,
        height=LEG_HEIGHT,
        face_material=pants,
        trim_material=pants,
        top_material=pants,
        base_z=LEG_Z0,
    )
    isobuild.box(
        "CustomerAdultTorso",
        center=TORSO_CENTER,
        width=TORSO_WIDTH,
        depth=TORSO_DEPTH,
        height=TORSO_HEIGHT,
        face_material=shirt,
        trim_material=shirt,
        top_material=shirt,
        base_z=TORSO_Z0,
    )
    isobuild.box(
        "CustomerAdultArmLeft",
        center=LEFT_ARM_CENTER,
        width=ARM_WIDTH,
        depth=ARM_DEPTH,
        height=ARM_HEIGHT,
        face_material=shirt,
        trim_material=shirt,
        top_material=shirt,
        base_z=ARM_Z0,
    )
    isobuild.box(
        "CustomerAdultArmRight",
        center=RIGHT_ARM_CENTER,
        width=ARM_WIDTH,
        depth=ARM_DEPTH,
        height=ARM_HEIGHT,
        face_material=shirt,
        trim_material=shirt,
        top_material=shirt,
        base_z=ARM_Z0,
    )
    isobuild.box(
        "CustomerAdultHead",
        center=HEAD_CENTER,
        width=HEAD_WIDTH,
        depth=HEAD_DEPTH,
        height=HEAD_HEIGHT,
        face_material=skin,
        trim_material=skin,
        top_material=skin,
        base_z=HEAD_Z0,
    )
    isobuild.box(
        "CustomerAdultHair",
        center=HAIR_CENTER,
        width=HAIR_WIDTH,
        depth=HAIR_DEPTH,
        height=HAIR_HEIGHT,
        face_material=hair,
        trim_material=hair,
        top_material=hair,
        base_z=HAIR_Z0,
    )

    #: Footprint corners span both leg boxes, not just one — the walk pose's
    #: ground contact is the bounding box of forward+back legs: col ±0.025
    #: (half of LEG_WIDTH), row -0.095 to +0.095 (LEG_ROW_OFFSET ± half of
    #: LEG_DEPTH).
    half_w = LEG_WIDTH / 2.0
    row_min = -LEG_ROW_OFFSET - LEG_DEPTH / 2.0
    row_max = LEG_ROW_OFFSET + LEG_DEPTH / 2.0
    return {
        "base_center": (0.0, 0.0, 0.0),
        "top_center": (HAIR_CENTER[0], HAIR_CENTER[1], TOTAL_HEIGHT),
        "base_corner_north": (-half_w, row_min, 0.0),
        "base_corner_east": (half_w, row_min, 0.0),
        "base_corner_south": (half_w, row_max, 0.0),
        "base_corner_west": (-half_w, row_max, 0.0),
    }
