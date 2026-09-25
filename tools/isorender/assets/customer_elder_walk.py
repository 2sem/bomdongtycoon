"""Elder customer, mid-stride walk pose — same body plan and colours as
`customer_elder_idle.py` (see that module's docstring for the `SCALE =
0.933` rescale reasoning); differs only in the legs, same way
`customer_adult_walk.py` differs from `customer_adult_idle.py`: one slab
replaced by two, staggered along the row axis, the customer's line of
travel in this scene.
"""

import isobuild

SCALE = 0.933

CANVAS_UNITS = 1.2 * SCALE
LOOK_AT = (0.0, 0.0, 0.30 * SCALE)
OUTLINE_PX = 0.45

SKIN_RGBA = (0.85, 0.68, 0.53, 1.0)
HAIR_RGBA = (0.78, 0.77, 0.73, 1.0)
SHIRT_RGBA = (0.45, 0.48, 0.35, 1.0)
PANTS_RGBA = (0.32, 0.27, 0.24, 1.0)

LEG_WIDTH = 0.05 * SCALE
LEG_DEPTH = 0.07 * SCALE
LEG_HEIGHT = 0.24 * SCALE
LEG_Z0 = 0.0
LEG_ROW_OFFSET = 0.06 * SCALE
LEG_FORWARD_CENTER = (0.0, LEG_ROW_OFFSET)
LEG_BACK_CENTER = (0.0, -LEG_ROW_OFFSET)

TORSO_CENTER = (0.0, 0.0)
TORSO_WIDTH = 0.16 * SCALE
TORSO_DEPTH = 0.10 * SCALE
TORSO_HEIGHT = 0.18 * SCALE
TORSO_Z0 = 0.24 * SCALE

ARM_WIDTH = 0.07 * SCALE
ARM_DEPTH = 0.12 * SCALE
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
HAIR_Z0 = 0.53 * SCALE

TOTAL_HEIGHT = HAIR_Z0 + HAIR_HEIGHT  # 0.569


def build():
    skin = isobuild.flat_material("CustomerElderSkin", texture=None, rgba=SKIN_RGBA)
    hair = isobuild.flat_material("CustomerElderHair", texture=None, rgba=HAIR_RGBA)
    shirt = isobuild.flat_material("CustomerElderShirt", texture=None, rgba=SHIRT_RGBA)
    pants = isobuild.flat_material("CustomerElderPants", texture=None, rgba=PANTS_RGBA)

    isobuild.box(
        "CustomerElderLegForward",
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
        "CustomerElderLegBack",
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

    #: Footprint corners span both leg boxes — same convention as
    #: `customer_adult_walk.py`.
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
