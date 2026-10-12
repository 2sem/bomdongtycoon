"""The pojangmacha stall's north wall — tier 0's stand-in for the walled
shop's `wall_shop_back`. Same North -> West diamond edge, so it drops into
`ShopNode.buildWalls`' back-wall loop with no placement change, only the
material and plank read changing underneath.

`HEIGHT`/`THICKNESS` are `wall_shop_left.py`'s own numbers, reused verbatim
rather than re-picked: this tier-0 stall has to read as the *same-size*
enclosure as the tier-1 wood shop it stands in for — only cheaper-looking —
so the silhouette stays fixed and only the material and plank rhythm change.

`PLANK_COUNT` is 3, not the wood wall's 5: big canvas drop-panels rather than
narrow planks. That is itself the "cheaper/improvised" cue against the wood
wall's finer 5-plank rhythm — fewer, wider structural units, not a smaller
number picked for its own sake. `trim_material` is `pole_metal.png`, thin
sheet metal instead of thick wood end-grain: that panel *is* the corner post
for this set, since `wall()`'s end-cap sliver already carries whatever
`trim_material` it is handed — no separate pole asset is needed for the
tarp walls.

`TEXTURE_PLANKS` stays 0: `tarp_canvas.png` is a plain, unbanded panel (the
texture designer's own flatness pass found no seam structure to align
against — quadrant-luminance spread 0.004-0.02%), so each of the 3 slabs
gets its own even slice of it rather than a mapped band.
"""

import isobuild
from isogrid import DIAMOND_VERTICES

CANVAS_UNITS = 2.0
LOOK_AT = (-0.5, 0.0, 0.35)
OUTLINE_PX = 0.45   # same ink weight as the rest of the set — px/unit is fixed
                    # by isogrid regardless of CANVAS_UNITS.

HEIGHT = 0.709      # wall_shop_left.py's own HEIGHT, reused verbatim
THICKNESS = 0.06    # wall_shop_left.py's own THICKNESS, reused verbatim — sturdy/structural
PLANK_COUNT = 3
PLANK_GAP = 0.0
PLANK_STEP = 0.006  # same stagger convention as the wood wall's 5 planks
TEXTURE_PLANKS = 0  # tarp_canvas.png is unbanded; plain repeat per slab


def build():
    tarp = isobuild.flat_material(
        "StallWallTarp", texture="tarp_canvas.png", rgba=(0.767, 0.296, 0.178, 1.0)
    )
    post = isobuild.flat_material(
        "StallWallPost", texture="pole_metal.png", rgba=(0.273, 0.292, 0.312, 1.0)
    )

    isobuild.wall(
        "StallWallBack",
        start=DIAMOND_VERTICES["north"],
        end=DIAMOND_VERTICES["west"],
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
