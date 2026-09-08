"""The shop's cook/prep table — stands against the windowed north-east ("right")
wall (`ShopWallRightNode`), directly under the middle window, and runs along
the row axis: a long counter reaching south into the room from the wall, not
a small table sitting parallel to it. Bare surface, nothing on it yet; a bowl
will stand on `top_center` later.

The wall it backs onto is the North -> East diamond edge in this rig's local
frame (`DIAMOND_VERTICES["north"] = (-0.5, -0.5)`, `["east"] = (0.5, -0.5)`),
i.e. the row = -0.5 edge running along the col axis. The counter spans two
cells along the row axis, `(col: 0, row: 0)` and `(col: 0, row: 1)`, so its
long-axis (row) extent runs from the wall at row -0.5 down to the far cell's
south edge at row 1.5, with real clearance at each end rather than flush:

    back edge  (against the wall, row -0.5)   = -0.5 + 0.10 = -0.40
    front edge (against the far cell, row 1.5) =  1.5 - 0.15 =  1.35
    depth (long axis)  = 1.35 - (-0.40) = 1.75
    row_center         = (-0.40 + 1.35) / 2    = 0.475

0.10 units of clearance at the back leaves the table clear of the wall's own
thickness (~0.06, same order as `wall_shop_left.THICKNESS`) with a visible
air gap rather than sitting flush against it. 0.15 at the south end keeps the
counter inside its two-cell run rather than touching the next cell edge.

`width` (the short, col-axis side) is unchanged at 0.5 — it already read well
— centered at col 0, spanning col -0.25 to col 0.25: comfortably inside a
single column, clear of both neighbouring columns.
"""

import isobuild
from isogrid import DIAMOND_VERTICES

#: Footprint is now 1.75 long (row) x 0.5 wide (col), against the old 0.7 x
#: 0.5 — recomputed from the box's own screen-projected corners (world yaw
#: 135deg, elevation asin(0.61639)) so the whole counter renders with margin,
#: not carried over from the old one-cell framing.
CANVAS_UNITS = 2.6
LOOK_AT = (0.0, 0.475, 0.15)
OUTLINE_PX = 0.45   # matches wall_shop_left's ~0.6%-of-width ink weight

CENTER = (0.0, 0.475)
#: Footprint: long axis now runs along row (perpendicular into the room from
#: the wall), short axis along col (parallel to the wall) — the reverse of
#: the old, wrong orientation.
WIDTH = 0.5
DEPTH = 1.75
#: Wall height is 0.709 (see wall_shop_left.py). Re-judged at the new,
#: two-cell-long proportions against the rendered wall_shop_left art at
#: on-screen size (see delivery note): 0.3 (42% of wall height) still reads
#: as a clearly-lower counter, not dwarfed by its own new length, so kept
#: unchanged rather than assumed.
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
