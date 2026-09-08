"""The shop's cook/prep table — stands against the windowed north-east ("right")
wall (`ShopWallRightNode`), directly under the middle window. Bare surface,
nothing on it yet; a bowl will stand on `top_center` later.

The wall it backs onto is the North -> East diamond edge in this rig's local
frame (`DIAMOND_VERTICES["north"] = (-0.5, -0.5)`, `["east"] = (0.5, -0.5)`),
i.e. the row = -0.5 edge running along the col axis. In the live game that
wall runs along the shop's minimum-row edge across all three columns; the
manager placed this table at the render rig's cell (0, 0), the middle of that
run. So the footprint is centered at col 0, and pulled south (positive row,
away from the row = -0.5 edge) by half its depth plus real clearance:

    row_center = -0.5 + clearance + depth/2
               = -0.5 + 0.10       + 0.25    = -0.15

0.10 units of clearance leaves the table clear of the wall's own thickness
(~0.06, same order as `wall_shop_left.THICKNESS`) with a visible air gap
rather than sitting flush against it. `width` (0.7, along the col axis) stays
well inside the cell: half-width 0.35 leaves 0.15 clear on each side of
col = +-0.5, so the footprint never approaches a neighbouring cell.
"""

import isobuild
from isogrid import DIAMOND_VERTICES

CANVAS_UNITS = 1.4
LOOK_AT = (0.0, -0.15, 0.15)
OUTLINE_PX = 0.45   # matches wall_shop_left's ~0.6%-of-width ink weight

CENTER = (0.0, -0.15)
#: Footprint: longer along the wall (col) than deep (row), like real
#: furniture standing against a wall rather than free in the room.
WIDTH = 0.7
DEPTH = 0.5
#: Wall height is 0.709 (see wall_shop_left.py); a prep table has to read
#: clearly lower than the wall it backs onto, not just "shorter" — 0.3 is
#: 42% of that, judged against the rendered wall_shop_left art at on-screen
#: size (see delivery note) rather than trusted as a raw ratio.
HEIGHT = 0.3
#: Worktop slab thickness: thin relative to HEIGHT (13%), like a slab top
#: rather than a solid block — the legs read as most of the standing height.
TOP_THICKNESS = 0.04
#: Square leg cross-section, one notch lighter than the walls' own
#: THICKNESS (0.06) so the legs read as furniture framing, not wall stock.
LEG_THICKNESS = 0.05
#: Pulls each leg in from the footprint edge so the top overhangs slightly,
#: the amount matching the walls' THICKNESS (0.06) for set-wide consistency.
LEG_INSET = 0.06


def build():
    #: Two panels, reused as-is (texture designer confirmed no regrading):
    #: the shipped wall plank panel for the legs/apron/underside, matching
    #: wall_shop_left.py's own flat_material(...) call verbatim — prop_table
    #: has a single leg_material slot (unlike wall()'s separate face/trim),
    #: so plank_end.png (the wall's *trim* panel) has no slot to go in here.
    legs = isobuild.flat_material(
        "PrepTableLegs", texture="plank_wall.png", rgba=(0.72, 0.53, 0.34, 1.0)
    )
    #: New worktop panel; square and uncropped, so tiled 1:1 across the top
    #: face UV (prop_table's top face already maps 0..1 x 0..1) rather than
    #: sliced into a band the way the wall's texture_planks does.
    top = isobuild.flat_material(
        "PrepTableTop", texture="timber_worktop.png", rgba=(0.82, 0.64, 0.41, 1.0)
    )

    isobuild.prop_table(
        "KitchenPrepTable",
        center=CENTER,
        width=WIDTH,
        depth=DEPTH,
        height=HEIGHT,
        top_thickness=TOP_THICKNESS,
        leg_thickness=LEG_THICKNESS,
        leg_inset=LEG_INSET,
        top_material=top,
        leg_material=legs,
    )
    return {}
