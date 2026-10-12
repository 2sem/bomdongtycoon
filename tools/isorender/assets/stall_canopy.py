"""The pojangmacha stall's roof — a free-standing tarp-on-poles canopy over
the cooking area, built with `isobuild.prop_table()` the same way
`kitchen_prep_table.py` is, not `wall()`: it is not anchored to a grid edge,
it stands on its own four-leg footprint.

This module's local `(col, row)` frame is the *same* frame
`kitchen_prep_table.py` and `shop_cash_counter.py` already use, not the
shop's own west-corner-origin offsets the art director's brief describes the
footprint in (`ShopWallOpening`'s `x`/`y`, zero at the shop's north-west
corner). Reusing the prep table's own frame — col 0 = the table's own origin
column (the shop's middle column), row 0 = the right wall's row, increasing
row toward the entrance — lets every clearance below be checked directly
against `kitchen_prep_table.py`'s and `shop_cash_counter.py`'s own numbers
instead of re-deriving them through a second offset. `col` and `row` map to
the brief's west-corner frame as `nw_col = col + 1`, `nw_row = row` (only the
column origin shifts, since both frames already zero their row at the right
wall).

Footprint derivation:

    COL — west + middle column, not the counter's east column:
        west column spans   local col -1.5 to -0.5
        middle column spans local col -0.5 to  0.5  (the table's own column)
        combined span            = -1.5 to 0.5
        WIDTH  = 0.5 - (-1.5)    = 2.0
        col_center               = (-1.5 + 0.5) / 2 = -0.5
    Checked against the counter: `shop_cash_counter.py` places the counter's
    own footprint at local col 1.00-1.40 (east column) — 0.5 clear of this
    footprint's own east edge at col 0.5. The counter's column never enters
    the canopy at all, not even at a single point.

    ROW — back edge lines up with the prep table's own back edge, not the
    wall itself: `kitchen_prep_table.py` clears the wall's thickness by 0.10
    (back edge -0.40, wall at row -0.5). The canopy's support poles stand
    over that same cleared strip rather than re-deriving their own wall
    clearance, so:
        back edge (row)  = -0.40                  (== table's own back edge)
        DEPTH             = 1.40
        front edge (row)  = -0.40 + 1.40 = 1.00
        row_center         = (-0.40 + 1.00) / 2 = 0.30
    Checked against the table: the table's own reach is -0.40 to 1.35 (depth
    1.75). The canopy covers the back 1.40 of that 1.75 (80%), leaving the
    table's own front end — row 1.00 to 1.35, the `daejeopBowl` slot's own
    reach (`ShopNode.daejeopBowl`, slot 2, the worktop's "high-row end") —
    under open sky. That is deliberate, not a rounding leftover: it is what
    keeps this a "back-half" canopy honestly, not a full roof pretending to
    be one, and it leaves row 1.5-2.0 (the entrance/counter side) untouched
    entirely, well clear of `DEPTH`'s own front edge at 1.00.

    HEIGHT (underside of the canopy top) = 0.90, i.e. 0.191 above the walls'
    own 0.709 (`stall_wall_back.py` etc.) — inside the brief's 0.90-0.95
    range, picked at its low end so the eave gap reads as a gap rather than
    a second storey; checked against the rendered wall art at on-screen size
    (see the delivery note) and kept.

`TOP_THICKNESS` = 0.03, thinner than the prep table's own 0.04 slab — the
canopy top is a tarp sheet, not a solid worktop, so it should read thinner
than furniture. `LEG_THICKNESS` = 0.04, thinner than the table's own leg
0.05 — thin support poles, matching `pole_metal.png`'s already-thin read on
the tarp walls' own corner posts. `LEG_INSET` = 0.08, a touch more than the
table's own 0.06, so the tarp top overhangs its poles a little more visibly
than the table's worktop overhangs its legs — an eave, not just a tabletop.

ENGINEERING NOTE, carry verbatim to the developer: every other multi-cell
prop in this shop (`ShopPropFootprint.nearestCellSum`, used by the prep
table and cash counter) z-orders itself off its NEAREST-to-camera covered
cell, so it always draws over that cell's own ground/wall — see
`ShopNode.Slot`'s doc comment. This canopy needs the OPPOSITE rule: it must
never draw over anything nearer than itself, including the prep table and
its cook gauges, since it sits *above* them, not in front of them in the
painter's-order sense. So whatever footprint numbers get handed to
`ShopPropFootprint` for this piece must key its z-order off its FARTHEST
(lowest col+row) covered cell — its own back corner — not its nearest. In
this spec's own markers that is `base_corner_north` (`prop_table()`'s
naming: the `(col - width/2, row - depth/2)` corner, i.e. local col -1.5,
row -0.40), the mirror image of every other prop's own `nearestCellSum`.
This is exactly the gap `ShopNode.Slot`'s doc comment flags as unhandled
("a prop meant to be partially occluded by nearer scenery would need the
opposite rule — its farthest cell, not its nearest"), applied in the
direction of "never occludes" rather than "is occluded."
"""

import isobuild

CANVAS_UNITS = 3.8
LOOK_AT = (-0.5, 0.30, 0.45)
OUTLINE_PX = 0.45

CENTER = (-0.5, 0.30)
WIDTH = 2.0
DEPTH = 1.40
HEIGHT = 0.90
TOP_THICKNESS = 0.03
LEG_THICKNESS = 0.04
LEG_INSET = 0.08


def build():
    legs = isobuild.flat_material(
        "StallCanopyLegs", texture="pole_metal.png", rgba=(0.273, 0.292, 0.312, 1.0)
    )
    top = isobuild.flat_material(
        "StallCanopyTop", texture="tarp_canvas.png", rgba=(0.767, 0.296, 0.178, 1.0)
    )

    isobuild.prop_table(
        "StallCanopy",
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
