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
OUTLINE_PX = 1.0

HEIGHT = 0.709
THICKNESS = 0.06


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
    )
    return {}
