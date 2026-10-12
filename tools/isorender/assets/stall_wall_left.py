"""The pojangmacha stall's south-west wall — tier 0's stand-in for the walled
shop's `wall_shop_left`. Same West -> South diamond edge (see
`wall_shop_left.py`), so it drops into `ShopNode.buildWalls`' left-wall loop
unchanged; only the material and plank read differ from the wood wall.

Every geometry choice here mirrors `stall_wall_back.py` (same tier-0 stall,
same tarp/post material pair, same plank rhythm) — see that module's doc
comment for the reasoning behind `HEIGHT`/`THICKNESS` (reused verbatim from
`wall_shop_left.py` for silhouette parity), `PLANK_COUNT` = 3 (wide canvas
drops vs. the wood wall's 5 planks) and `TEXTURE_PLANKS` = 0 (tarp_canvas.png
is unbanded).
"""

import isobuild
from isogrid import DIAMOND_VERTICES

CANVAS_UNITS = 2.0
LOOK_AT = (0.0, 0.5, 0.35)
OUTLINE_PX = 0.45

HEIGHT = 0.709
THICKNESS = 0.06
PLANK_COUNT = 3
PLANK_GAP = 0.0
PLANK_STEP = 0.006
TEXTURE_PLANKS = 0


def build():
    tarp = isobuild.flat_material(
        "StallWallTarp", texture="tarp_canvas.png", rgba=(0.767, 0.296, 0.178, 1.0)
    )
    post = isobuild.flat_material(
        "StallWallPost", texture="pole_metal.png", rgba=(0.273, 0.292, 0.312, 1.0)
    )

    isobuild.wall(
        "StallWallLeft",
        start=DIAMOND_VERTICES["west"],
        end=DIAMOND_VERTICES["south"],
        height=HEIGHT,
        thickness=THICKNESS,
        face_material=tarp,
        trim_material=post,
        inward_toward=(0.0, 0.0),
        plank_count=PLANK_COUNT,
        plank_gap=PLANK_GAP,
        plank_step=PLANK_STEP,
        texture_planks=TEXTURE_PLANKS,
    )
    return {}
