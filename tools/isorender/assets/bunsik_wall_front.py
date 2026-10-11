"""Tier-1 (bunsikjip) south-east wall: South -> East edge, camera-near like
`wall_shop_left`. One framing post on the east end, and no baked entrance gap:
the game omits segments for the entrance."""

import isobuild
from isogrid import DIAMOND_VERTICES

CANVAS_UNITS = 2.0
LOOK_AT = (0.5, 0.0, 0.35)
OUTLINE_PX = 0.45   # same ink weight as wall_shop_left

HEIGHT = 0.709      # wall_shop_left's own numbers, reused verbatim
THICKNESS = 0.06
PLANK_COUNT = 5
PLANK_GAP = 0.0
PLANK_STEP = 0.006
TEXTURE_PLANKS = 11  # plank_wall.png draws 11 planks
POST = 0.07          # corner-post footprint (col and row)
POST_HEIGHT = HEIGHT + 0.02
#: A post stands POST_PROUD past the visible face, so it reads as a post
#: rather than a flush end.
POST_PROUD = 0.01


def build():
    planks = isobuild.flat_material(
        "BunsikWallFrontPlanks", texture="plank_wall.png", rgba=(0.72, 0.53, 0.34, 1.0)
    )
    trim = isobuild.flat_material(
        "BunsikWallFrontTrim", texture="plank_end.png", rgba=(0.62, 0.44, 0.28, 1.0)
    )
    isobuild.wall(
        "BunsikWallFront",
        start=DIAMOND_VERTICES["south"],
        end=DIAMOND_VERTICES["east"],
        height=HEIGHT,
        thickness=THICKNESS,
        face_material=planks,
        trim_material=trim,
        inward_toward=(0.0, 0.0),
        plank_count=PLANK_COUNT,
        plank_gap=PLANK_GAP,
        plank_step=PLANK_STEP,
        texture_planks=TEXTURE_PLANKS,
    )
    isobuild.box(
        "BunsikWallFrontPost0",
        center=(0.5 + POST_PROUD - POST / 2, -0.5 - POST_PROUD + POST / 2),
        width=POST,
        depth=POST,
        height=POST_HEIGHT,
        face_material=trim,
        trim_material=trim,
        top_material=trim,
    )
    return {}
