"""The shop's checkout counter, standing in the new two-cell opening on the
east-side front wall (`ShopNode.defaultOpenings`, shop-local offsets (2,0)
and (2,1)) — a solid, closed box rather than the prep table's open frame of
legs, so it reads as a fixture the cashier stands behind, not a second work
surface.

Long axis (row, parallel to the opening) reuses the prep table's own span
verbatim rather than a fresh number: both pieces occupy the shop's two rows
nearest the windowed wall, so there is no reason for the counter's row reach
to differ from `kitchen_prep_table.py`'s:

    back edge  (row -0.40)         = -0.5 + 0.10   (unchanged clearance)
    front edge (row  1.35)         =  1.5 - 0.15    (unchanged clearance)
    depth (long axis) = 1.35 - (-0.40) = 1.75
    row_center         = (-0.40 + 1.35) / 2 = 0.475

Short axis (col, into the room) is new — the counter sits near the opening
at col +1.5 (where the removed wall segment used to run), not against a
solid wall the way the prep table sits against its own. There is no wall
thickness to clear here — the opening is a gap, not a wall of a known
thickness — so the clearance off that edge is a judgement call rather than
a "clear the wall stock" number: 0.10, the same order as the prep table's
own back clearance, keeps the counter visibly inside the opening rather
than flush with the tile boundary (a fixture flush with an open edge reads
like it is floating off the map; a small setback reads like it was placed
there on purpose).

    outer edge (near the opening) = 1.5 - 0.10 = 1.40
    WIDTH (col axis)              = 0.40
    inner edge (room side)        = 1.40 - 0.40 = 1.00
    col_center                    = (1.40 + 1.00) / 2 = 1.20

Checked against both neighbours this creates:
  * the prep table's own footprint ends at col 0.25 (center col 0, width
    0.5) — the counter's inner edge at col 1.00 leaves 0.75 units of clear
    floor between them, three-quarters of a full cell, comfortably wide
    for the cashier to stand and move behind the counter without crowding
    the prep table's aisle.
  * WIDTH 0.40 leaves the counter itself well short of a full cell (1.0),
    so col 1.00-1.40 alone doesn't reach the shop's middle column at all —
    it sits entirely inside the opening's own column, exactly where a
    built-in counter would.

HEIGHT 0.4 is the manager's starting guess (a waist-to-chest checkout
counter) and held after inspecting the render against both neighbours at
on-screen size: at 0.4 it reads as 133% of the prep table's 0.3 (clearly
taller, matching a standing-height counter vs. a waist-height worktop) and
56% of the wall's 0.709 (clearly under the wall, not competing with it) —
kept rather than re-tuned.
"""

import isobuild

CANVAS_UNITS = 2.15
LOOK_AT = (1.20, 0.475, 0.20)
OUTLINE_PX = 0.45  # reused verbatim from wall_shop_left / kitchen_prep_table:
                    # pixels-per-world-unit is fixed by isogrid regardless of
                    # CANVAS_UNITS, so the same OUTLINE_PX is the same ink
                    # weight in the final image across the whole set.

CENTER = (1.20, 0.475)
WIDTH = 0.40   # col axis, into the room
DEPTH = 1.75   # row axis, parallel to the opening — same span as the prep table
HEIGHT = 0.40


def build():
    #: Sides: the shipped wall-plank panel, same as wall_shop_left's face and
    #: kitchen_prep_table's legs — one more piece in the same timber set.
    face = isobuild.flat_material(
        "CashCounterFace", texture="plank_wall.png", rgba=(0.72, 0.53, 0.34, 1.0)
    )
    #: Trim (bottom, never seen): box() gives a dedicated trim slot the way
    #: wall() does (unlike prop_table's single leg_material), so it takes
    #: wall_shop_left's own trim panel rather than reusing the face panel —
    #: the box() interface is built to mirror wall()'s split, not
    #: prop_table's.
    trim = isobuild.flat_material(
        "CashCounterTrim", texture="plank_end.png", rgba=(0.62, 0.44, 0.28, 1.0)
    )
    #: Top: the prep table's own worktop panel, tiled 1:1 uncropped across
    #: the top face UV — same convention prop_table's top face already uses.
    top = isobuild.flat_material(
        "CashCounterTop", texture="timber_worktop.png", rgba=(0.82, 0.64, 0.41, 1.0)
    )

    isobuild.box(
        "ShopCashCounter",
        center=CENTER,
        width=WIDTH,
        depth=DEPTH,
        height=HEIGHT,
        face_material=face,
        trim_material=trim,
        top_material=top,
    )
    return {}
