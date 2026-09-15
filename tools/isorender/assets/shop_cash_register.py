"""A small standalone cash register, rendered in its own local frame at grid
origin like a crate or any other free-standing prop — NOT elevated in
Blender space to the counter's height. Whoever writes the Swift node stacks
it onto `shop_cash_counter`'s `top_center` pixel position using this
sprite's own `base_center` anchor fraction, the same anchor-fraction
composition every other piece in this set already uses; that composition is
not this module's concern.

Two `box()` parts, not one, so it reads as a register rather than a plain
crate: a wider, lower **body** (the till/drawer housing) and a smaller,
darker **accent** block stacked on its back portion (the keypad/screen).

Body footprint: 0.28 (col) x 0.20 (row), comfortably inside the counter's
own WIDTH (0.40) with 0.06 of clearance on each side — it sits on the
counter's surface, not overhanging it — and small next to the counter's
DEPTH (1.75), leaving most of the worktop visibly bare. Body height 0.12.

Accent: 0.16 x 0.10, set on the body's back portion (offset toward -row so
it's flush with the body's back edge at row -0.10, `center row = -0.10 +
0.10/2 = -0.05`) rather than centered on the body — a real register's
keypad/screen block sits toward the back, leaving the front half of the
body's top (rows 0.00 to 0.10) exposed as a tray, not covered edge to edge.
Accent height 0.05, stacked at `base_z = 0.12` (the body's own height).

Total height 0.12 + 0.05 = 0.17, 43% of the counter's own 0.4 — "well
under" and "distinctly smaller," the same order of ratio as the prep
table's 0.3 sitting under the wall's 0.709 (42%), which already reads as a
clear two-tier size difference in this set — so this register-on-counter
pairing should read the same way once composed.

Both blocks are flat colour, no texture (texture designer's numbers, no
regrading needed): the body a warm, deliberately darker/redder brown than
the wall/counter/prep-table timber family (the "distinct fixture" cue), the
accent a near-black warm dark for the screen/keypad. The accent's sides
reuse the body's own colour rather than a second dark tone — the screen
face (top) is the only part that needs to read as glass/keys; painting the
accent's sides the same near-black as its top made the small block look
like a separate dark box floating on the body rather than one moulded
unit with a dark face on top, so the body colour on its sides was the
better read, checked at render.
"""

import isobuild

CANVAS_UNITS = 0.55
LOOK_AT = (0.0, 0.0, 0.085)
OUTLINE_PX = 0.45  # same ink weight as the rest of the set (see
                    # shop_cash_counter.py: pixels-per-world-unit is fixed by
                    # isogrid regardless of CANVAS_UNITS, so this is the same
                    # absolute line thickness everywhere).

BODY_CENTER = (0.0, 0.0)
BODY_WIDTH = 0.28
BODY_DEPTH = 0.20
BODY_HEIGHT = 0.12

ACCENT_CENTER = (0.0, -0.05)
ACCENT_WIDTH = 0.16
ACCENT_DEPTH = 0.10
ACCENT_HEIGHT = 0.05

BODY_RGBA = (0.408, 0.204, 0.149, 1.0)    # target mean ~= RGB 104,52,38
ACCENT_TOP_RGBA = (0.110, 0.086, 0.075, 1.0)  # target mean ~= RGB 28,22,19


def build():
    body_color = isobuild.flat_material("RegisterBody", texture=None, rgba=BODY_RGBA)
    accent_top = isobuild.flat_material(
        "RegisterAccentTop", texture=None, rgba=ACCENT_TOP_RGBA
    )

    isobuild.box(
        "ShopCashRegisterBody",
        center=BODY_CENTER,
        width=BODY_WIDTH,
        depth=BODY_DEPTH,
        height=BODY_HEIGHT,
        face_material=body_color,
        trim_material=body_color,
        top_material=body_color,
    )
    isobuild.box(
        "ShopCashRegisterAccent",
        center=ACCENT_CENTER,
        width=ACCENT_WIDTH,
        depth=ACCENT_DEPTH,
        height=ACCENT_HEIGHT,
        face_material=body_color,
        trim_material=body_color,
        top_material=accent_top,
        base_z=BODY_HEIGHT,
    )

    #: Two box() calls emit identically-named markers ("base_center",
    #: "base_corner_north/east/south/west", "top_center"); `rig.py`'s
    #: `collect_markers` merges every object's markers into one flat dict by
    #: name, so whichever box iterates last silently wins and the accent's
    #: elevated base would clobber the body's ground-level one. `build()`'s
    #: return value is applied last (`collect_markers(extra)` -> `markers.
    #: update(extra)`), so overriding here with the body's own footprint —
    #: the register's true resting point on the counter — is what makes the
    #: reported anchor correct regardless of Blender's object-iteration
    #: order. `top_center` is reported as the accent's own top: the highest
    #: point of the assembled register, not a stacking point anything else
    #: uses.
    bcol, brow = BODY_CENTER
    bhw, bhd = BODY_WIDTH / 2.0, BODY_DEPTH / 2.0
    acol, arow = ACCENT_CENTER
    return {
        "base_center": (bcol, brow, 0.0),
        "top_center": (acol, arow, BODY_HEIGHT + ACCENT_HEIGHT),
        "base_corner_north": (bcol - bhw, brow - bhd, 0.0),
        "base_corner_east": (bcol + bhw, brow - bhd, 0.0),
        "base_corner_south": (bcol + bhw, brow + bhd, 0.0),
        "base_corner_west": (bcol - bhw, brow + bhd, 0.0),
    }
