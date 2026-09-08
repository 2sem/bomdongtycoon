"""The shop's south-west wall — `Sources/App/Nodes/Shop/ShopWallLeftNode.swift`.

Sits on cell (0, 0)'s West -> South diamond edge, so its visible face recedes
upper-left to lower-right (`\\` in the agent brief's terms). Thickness is
extruded toward the cell center, which is what shows as the end-cap sliver on
the South end and the lit strip along the top.

`HEIGHT` is picked to reproduce the shipped sprite's proportions rather than
to look right on its own, so this render can be compared against
`wall_shop_left.png` directly: that art's 410 px face at the node's
`scaleY` of 38.83/320 is ~49.7 pt of screen height, and screen height is world
height times `cos(elevation)`, giving 49.7 / 0.78745 / 89.095 ~ 0.709 units.
"""

import isobuild
from isogrid import DIAMOND_VERTICES

CANVAS_UNITS = 2.0
LOOK_AT = (0.0, 0.5, 0.35)
OUTLINE_PX = 0.45   # ~0.6% of the sprite's width, matching the shipped art

HEIGHT = 0.709
THICKNESS = 0.06
#: The shipped set reads as five stacked planks with an ink seam between each
#: and a stepped end cap — count them on `wall_shop_front.png`. That is
#: geometry, not texture, so the rig builds it.
PLANK_COUNT = 5
PLANK_GAP = 0.0
PLANK_STEP = 0.006
#: How many planks `plank_wall.png` itself draws, so each slab can be mapped
#: to one whole plank of it rather than showing the panel's seams on top of
#: the geometry's.
TEXTURE_PLANKS = 11


def build():
    planks = isobuild.flat_material(
        "ShopWallPlanks", texture="plank_wall.png", rgba=(0.72, 0.53, 0.34, 1.0)
    )
    trim = isobuild.flat_material(
        "ShopWallTrim", texture="plank_end.png", rgba=(0.62, 0.44, 0.28, 1.0)
    )

    isobuild.wall(
        "ShopWallLeft",
        start=DIAMOND_VERTICES["west"],
        end=DIAMOND_VERTICES["south"],
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
    return {}
