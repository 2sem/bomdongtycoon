"""The pojangmacha stall's south-east wall — tier 0's stand-in for the walled
shop's `wall_shop_front`. Same South -> East diamond edge, so it drops into
`ShopNode.buildWalls`' front-wall loop unchanged. Every geometry number here
is identical to `stall_curtain_right.py` — same wall, same material pair,
same reasoning for `HEIGHT`/`THICKNESS`/`PLANK_COUNT` — see that module's doc
comment.

One thing this module deliberately does *not* do: replicate the shipped
`wall_shop_front.png`'s baked-in entrance gap. `ShopWallFrontNode`'s "KNOWN
COSMETIC ISSUE" comment (see `ShopNode.buildWalls`) flags that gap as an
artifact of that one hand-drawn source image, not a feature of the wall — it
shows up on every `ShopWallFrontNode` segment, including ones nowhere near
the actual entrance. This spec is rig-rendered fresh with no such artifact to
carry over, so it builds a single plain, uniform sheet like every other
curtain/tarp panel in the set. The real entrance gap is handled the same way
the existing wood shop already handles it: at the Swift level, by
`ShopNode.defaultOpenings` simply not placing a wall segment in the opening's
two cells — never by baking a gap into the art.
"""

import isobuild
from isogrid import DIAMOND_VERTICES

CANVAS_UNITS = 2.0
LOOK_AT = (0.5, 0.0, 0.35)
OUTLINE_PX = 0.45

HEIGHT = 0.709
THICKNESS = 0.03
PLANK_COUNT = 1
PLANK_GAP = 0.0
PLANK_STEP = 0.0
TEXTURE_PLANKS = 0


def build():
    curtain = isobuild.flat_material(
        "StallCurtainPlastic", texture="curtain_plastic.png", rgba=(0.880, 0.802, 0.645, 1.0)
    )
    post = isobuild.flat_material(
        "StallWallPost", texture="pole_metal.png", rgba=(0.273, 0.292, 0.312, 1.0)
    )

    isobuild.wall(
        "StallCurtainFront",
        start=DIAMOND_VERTICES["south"],
        end=DIAMOND_VERTICES["east"],
        height=HEIGHT,
        thickness=THICKNESS,
        face_material=curtain,
        trim_material=post,
        inward_toward=(0.0, 0.0),
        plank_count=PLANK_COUNT,
        plank_gap=PLANK_GAP,
        plank_step=PLANK_STEP,
        texture_planks=TEXTURE_PLANKS,
    )
    return {}
