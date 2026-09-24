"""Kid customer, standing/idle pose — the same six-box peg-doll body plan as
`customer_adult_idle.py` (legs/torso/2 arms/head/hair), uniformly rescaled by
`SCALE = 0.70` and recoloured so it reads as a distinct customer rather than
a smaller copy of the adult. See `customer_adult_idle.py`'s docstring for the
shared reasoning (why boxes, why flat colour, the marker-override pattern).

`SCALE` multiplies every one of the adult module's own numbers — position
offsets and sizes alike — so the whole body plan shrinks uniformly around
the shared origin `(col=0, row=0, z=0)`, the figure's own ground-contact
point. Total standing height becomes 0.61 x 0.70 = 0.427.

Known simplification, deliberate for this v1 pass, not an oversight: this is
a proportionally shrunk adult, not true child proportions (a child's head is
relatively larger and its legs relatively shorter than an adult's). If it
reads as "shrunken adult" rather than "child" once composed next to the
counter, the usual fix is a bigger relative head — a same-file rescale of
`HEAD_*`/`HAIR_*` against the rest, not a rig question. Worth revisiting
after this pilot is judged in-scene.

Colours: skin and pants stay the adult's own (skin tone doesn't vary by
archetype here; pants/trouser colour doesn't need to either). Hair and shirt
change so this reads as a different person, not a scaled-down clone of the
same one — lighter warm-brown hair, a warm red-orange shirt distinct from
both the timber family (185,121,57) and the adult's cool teal.
"""

import isobuild

SCALE = 0.70

CANVAS_UNITS = 1.2 * SCALE
LOOK_AT = (0.0, 0.0, 0.30 * SCALE)
OUTLINE_PX = 0.45  # absolute ink weight, same as every other piece in this
                    # set — not scaled down with the figure.

SKIN_RGBA = (0.85, 0.68, 0.53, 1.0)    # same as adult — target mean ~RGB(217,173,135)
HAIR_RGBA = (0.40, 0.26, 0.16, 1.0)    # target mean ~RGB(102,66,41) — lighter warm
                                        # brown than the adult's near-black
SHIRT_RGBA = (0.75, 0.32, 0.26, 1.0)   # target mean ~RGB(191,82,66) — warm
                                        # red-orange, playful, clear of both the
                                        # timber family and the adult's teal
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

TOTAL_HEIGHT = HAIR_Z0 + HAIR_HEIGHT  # 0.427


def build():
    skin = isobuild.flat_material("CustomerKidSkin", texture=None, rgba=SKIN_RGBA)
    hair = isobuild.flat_material("CustomerKidHair", texture=None, rgba=HAIR_RGBA)
    shirt = isobuild.flat_material("CustomerKidShirt", texture=None, rgba=SHIRT_RGBA)
    pants = isobuild.flat_material("CustomerKidPants", texture=None, rgba=PANTS_RGBA)

    isobuild.box(
        "CustomerKidLegs",
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
        "CustomerKidTorso",
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
        "CustomerKidArmLeft",
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
        "CustomerKidArmRight",
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
        "CustomerKidHead",
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
        "CustomerKidHair",
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
