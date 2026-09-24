"""Elder customer, standing/idle pose — the same six-box peg-doll body plan
as `customer_adult_idle.py`, uniformly rescaled by `SCALE = 0.933` and
recoloured. See `customer_adult_idle.py`'s docstring for the shared
reasoning (why boxes, why flat colour, the marker-override pattern).

Unlike the kid archetype, this is a shorter adult, not a differently
proportioned one — `SCALE` applies the same way (every position offset and
size in the adult module, multiplied uniformly), just with a ratio close to
1 rather than the kid's 0.70, since an elder customer's proportions don't
diverge from an adult's the way a child's do. Total standing height becomes
0.61 x 0.933 = 0.569.

Colours: skin and pants stay the adult's own. Hair goes grey-white; shirt
goes to a muted sage/olive, distinct from the timber family, the adult's
teal, and the kid's red-orange.
"""

import isobuild

SCALE = 0.933

CANVAS_UNITS = 1.2 * SCALE
LOOK_AT = (0.0, 0.0, 0.30 * SCALE)
OUTLINE_PX = 0.45  # absolute ink weight, same as every other piece in this
                    # set — not scaled down with the figure.

SKIN_RGBA = (0.85, 0.68, 0.53, 1.0)    # same as adult — target mean ~RGB(217,173,135)
HAIR_RGBA = (0.78, 0.77, 0.73, 1.0)    # target mean ~RGB(199,196,186) — grey-white
SHIRT_RGBA = (0.45, 0.48, 0.35, 1.0)   # target mean ~RGB(115,122,89) — muted sage/olive
PANTS_RGBA = (0.32, 0.27, 0.24, 1.0)   # same as adult — target mean ~RGB(82,69,61)

LEGS_CENTER = (0.0, 0.0)
LEGS_WIDTH = 0.10 * SCALE
LEGS_DEPTH = 0.08 * SCALE
LEGS_HEIGHT = 0.24 * SCALE
LEGS_Z0 = 0.0

TORSO_CENTER = (0.0, 0.0)
TORSO_WIDTH = 0.16 * SCALE
TORSO_DEPTH = 0.10 * SCALE
TORSO_HEIGHT = 0.18 * SCALE
TORSO_Z0 = 0.24 * SCALE

ARM_WIDTH = 0.07 * SCALE
ARM_DEPTH = 0.12 * SCALE   # deeper than the torso's own depth, same as the
                            # adult, so the arm pokes past the torso's row
                            # footprint on both sides, not just its col one
ARM_HEIGHT = 0.16 * SCALE
ARM_Z0 = 0.25 * SCALE
ARM_OFFSET_COL = 0.115 * SCALE
LEFT_ARM_CENTER = (-ARM_OFFSET_COL, 0.0)
RIGHT_ARM_CENTER = (ARM_OFFSET_COL, 0.0)

HEAD_CENTER = (0.0, 0.0)
HEAD_WIDTH = 0.14 * SCALE
HEAD_DEPTH = 0.12 * SCALE
HEAD_HEIGHT = 0.18 * SCALE
HEAD_Z0 = 0.42 * SCALE

HAIR_CENTER = (0.0, 0.0)
HAIR_WIDTH = 0.15 * SCALE
HAIR_DEPTH = 0.13 * SCALE
HAIR_HEIGHT = 0.08 * SCALE
HAIR_Z0 = 0.53 * SCALE  # head's own top is at 0.60*SCALE; hair's top lands at
                         # 0.61*SCALE — clear of it, not coincident, carrying
                         # forward the adult module's own z-fighting fix.

TOTAL_HEIGHT = HAIR_Z0 + HAIR_HEIGHT  # 0.569


def build():
    skin = isobuild.flat_material("CustomerElderSkin", texture=None, rgba=SKIN_RGBA)
    hair = isobuild.flat_material("CustomerElderHair", texture=None, rgba=HAIR_RGBA)
    shirt = isobuild.flat_material("CustomerElderShirt", texture=None, rgba=SHIRT_RGBA)
    pants = isobuild.flat_material("CustomerElderPants", texture=None, rgba=PANTS_RGBA)

    isobuild.box(
        "CustomerElderLegs",
        center=LEGS_CENTER,
        width=LEGS_WIDTH,
        depth=LEGS_DEPTH,
        height=LEGS_HEIGHT,
        face_material=pants,
        trim_material=pants,
        top_material=pants,
        base_z=LEGS_Z0,
    )
    isobuild.box(
        "CustomerElderTorso",
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
        "CustomerElderArmLeft",
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
        "CustomerElderArmRight",
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
        "CustomerElderHead",
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
        "CustomerElderHair",
        center=HAIR_CENTER,
        width=HAIR_WIDTH,
        depth=HAIR_DEPTH,
        height=HAIR_HEIGHT,
        face_material=hair,
        trim_material=hair,
        top_material=hair,
        base_z=HAIR_Z0,
    )

    lcol, lrow = LEGS_CENTER
    lhw, lhd = LEGS_WIDTH / 2.0, LEGS_DEPTH / 2.0
    return {
        "base_center": (lcol, lrow, 0.0),
        "top_center": (HAIR_CENTER[0], HAIR_CENTER[1], TOTAL_HEIGHT),
        "base_corner_north": (lcol - lhw, lrow - lhd, 0.0),
        "base_corner_east": (lcol + lhw, lrow - lhd, 0.0),
        "base_corner_south": (lcol + lhw, lrow + lhd, 0.0),
        "base_corner_west": (lcol - lhw, lrow + lhd, 0.0),
    }
