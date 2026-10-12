"""The pojangmacha stall's north-east wall — tier 0's stand-in for the walled
shop's windowed `wall_shop_right`, the wall the prep table backs onto. Same
North -> East diamond edge, so it drops into `ShopNode.buildWalls`'
right-wall loop unchanged.

`HEIGHT` stays `wall_shop_left.py`'s 0.709 for the same silhouette-parity
reason as the tarp walls (`stall_wall_back.py`/`stall_wall_left.py`) — every
enclosure wall in this set, tarp or curtain, has to top out at the same
height so the stall reads as one consistent box.

`THICKNESS` is 0.03, half the tarp walls' 0.06: this is the "flimsy hanging
sheet" wall, not the "sturdy canvas" one, and thinness is the one geometric
lever that sells that without touching the rig. `PLANK_COUNT` is 1 — one
continuous sheet, no internal seam — deliberately *less* structured than the
tarp walls' 3, not just a smaller number: a curtain has no stacked-slab
construction to show a seam for. With only one slab, `PLANK_GAP`/
`PLANK_STEP` have nothing to act on (`wall()` only applies either when
`index < plank_count - 1`, which is never true at `plank_count=1`), so both
are set to 0.0 for clarity rather than left to a default that would be a
no-op anyway.

`trim_material` stays `pole_metal.png`, the same thin post panel as the tarp
walls — same corner-post read set-wide, `THICKNESS` alone (not a different
trim) is what tells the curtain wall apart from its tarp neighbours.
`TEXTURE_PLANKS` is left 0: `curtain_plastic.png` is a plain hazy panel with
no banded structure to map against, same as `tarp_canvas.png`.
"""

import isobuild
from isogrid import DIAMOND_VERTICES

CANVAS_UNITS = 2.0
LOOK_AT = (0.0, -0.5, 0.35)
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
        "StallCurtainRight",
        start=DIAMOND_VERTICES["north"],
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
