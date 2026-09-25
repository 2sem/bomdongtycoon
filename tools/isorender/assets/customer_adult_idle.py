"""Pilot customer figure — standing/idle pose, for the shop-customers walk-in
flow (road -> counter -> order -> wait -> leave). No customer geometry exists
anywhere in this rig yet, so this is a from-scratch body plan built entirely
from `isobuild.box()` — a "peg-doll" minifig: stacked axis-aligned boxes for
legs/torso/arms/head/hair, flat colours, no painted face. At the ~40pt
on-screen height this renders at, that chunky silhouette is more readable
than a modelled face would be, and it is exactly what `box()` can express
without any rig change — the same reasoning `shop_cash_register.py` already
applies for a two-box prop, just with six boxes instead of two.

Local rig origin `(col=0, row=0)` is the figure's own ground-contact point,
the same convention `shop_cash_register.py` uses for its own free-standing
local frame — whoever writes the Swift node composes this onto the scene by
anchor fraction, same as every other piece in this set.

Sizing: total standing height 0.60 world units was picked by the art
director so the shop's cash counter top (`shop_cash_counter.py` HEIGHT=0.40)
lands at 0.40/0.60 = 67% of the figure's height — roughly chest-height on an
adult, the way a real checkout counter reads against a customer standing at
it. Six parts, one box() call each:

  legs (single slab, feet together for idle) — z 0.0 to 0.24
  torso                                       — z 0.24 to 0.42
  arms x2 (proud of the torso in both col and row, not just col, so they
    step out of its silhouette from this camera angle; inset in z so they
    read as sleeves, not full-height slabs poking above the shoulder line
    or below the hip) — z 0.25 to 0.41
  head                                        — z 0.42 to 0.60
  hair cap (overhanging every side so it reads as a hair silhouette rather
    than a floating slab on the scalp) — z 0.53 to 0.61

Revision note (post-pilot-review): the hair cap's top was originally flush
with the head's own top (both at z=0.60) — a real defect, not a style
choice: two outward, camera-facing top faces occupying the exact same plane
over the same footprint rendered as solid black instead of blending,
confirmed by isolated pixel sampling against this rig's own known-good
lighting behaviour on `shop_cash_register.py`. Fixed by giving the hair's
top daylight above the head's (z1 0.61 vs 0.60) rather than coincident with
it. Total figure height is now 0.61, not 0.60. Arms were also widened past
the torso's own row extent (not just its col extent) after the pilot render
showed no visible shoulder bump — a plain col-only offset at the original
0.05x0.09 size stayed coplanar with the torso's own row footprint and never
broke its silhouette from this camera angle.

Six box() calls all emit colliding `base_center`/`top_center`/
`base_corner_*` markers (`rig.py`'s `collect_markers` keeps whichever
object's happens to iterate last), so `build()` overrides them by hand —
same fix as `shop_cash_register.py`'s two-box case, just re-derived from the
legs box instead of the body box: `base_center` is the ground/feet contact
point, `top_center` is the hair cap's own top (for a future thought-bubble
overlay), and the four `base_corner_*` markers are the legs box's own
footprint (the only part touching the ground in this pose).
"""

import isobuild

CANVAS_UNITS = 1.2
LOOK_AT = (0.0, 0.0, 0.30)
OUTLINE_PX = 0.45  # same ink weight as the rest of the set — pixels-per-world-unit
                    # is fixed by isogrid regardless of CANVAS_UNITS.

SKIN_RGBA = (0.85, 0.68, 0.53, 1.0)    # target mean ~RGB(217,173,135)
HAIR_RGBA = (0.25, 0.16, 0.10, 1.0)    # target mean ~RGB(64,41,26)
SHIRT_RGBA = (0.30, 0.45, 0.50, 1.0)   # target mean ~RGB(77,115,128) — cool teal,
                                        # deliberately unlike the warm timber
                                        # family (185,121,57) so the figure pops
                                        # against walls/counter rather than
                                        # camouflaging into them
PANTS_RGBA = (0.32, 0.27, 0.24, 1.0)   # target mean ~RGB(82,69,61) — warm
                                        # brown-grey; the original cool
                                        # grey-blue (0.28,0.30,0.36) read too
                                        # close to metal/robot legs next to
                                        # the warm timber counter and the
                                        # teal shirt once composed

LEGS_CENTER = (0.0, 0.0)
LEGS_WIDTH = 0.10
LEGS_DEPTH = 0.08
LEGS_HEIGHT = 0.24
LEGS_Z0 = 0.0

TORSO_CENTER = (0.0, 0.0)
TORSO_WIDTH = 0.16
TORSO_DEPTH = 0.10
TORSO_HEIGHT = 0.18
TORSO_Z0 = 0.24

ARM_WIDTH = 0.07   # was 0.05
ARM_DEPTH = 0.12   # was 0.09 — deeper than the torso's own 0.10, so the arm
                    # pokes past the torso's row footprint on both sides,
                    # not just its col footprint
ARM_HEIGHT = 0.16
ARM_Z0 = 0.25
ARM_OFFSET_COL = 0.115  # torso half-width 0.08 + new arm half-width 0.035
LEFT_ARM_CENTER = (-ARM_OFFSET_COL, 0.0)
RIGHT_ARM_CENTER = (ARM_OFFSET_COL, 0.0)

HEAD_CENTER = (0.0, 0.0)
HEAD_WIDTH = 0.14
HEAD_DEPTH = 0.12
HEAD_HEIGHT = 0.18
HEAD_Z0 = 0.42

HAIR_CENTER = (0.0, 0.0)
HAIR_WIDTH = 0.15
HAIR_DEPTH = 0.13
HAIR_HEIGHT = 0.08  # was 0.06
HAIR_Z0 = 0.53       # was 0.54 — z1 = 0.61, strictly above HEAD's own
                      # z1 = 0.60 instead of coincident with it

TOTAL_HEIGHT = HAIR_Z0 + HAIR_HEIGHT  # 0.61


def build():
    skin = isobuild.flat_material("CustomerSkin", texture=None, rgba=SKIN_RGBA)
    hair = isobuild.flat_material("CustomerHair", texture=None, rgba=HAIR_RGBA)
    shirt = isobuild.flat_material("CustomerShirt", texture=None, rgba=SHIRT_RGBA)
    pants = isobuild.flat_material("CustomerPants", texture=None, rgba=PANTS_RGBA)

    isobuild.box(
        "CustomerAdultLegs",
        center=LEGS_CENTER,
        width=LEGS_WIDTH,
        depth=LEGS_DEPTH,
        height=LEGS_HEIGHT,
        face_material=pants,
        trim_material=pants,
        top_material=pants,
        base_z=LEGS_Z0,
    )
    isobuild.box(
        "CustomerAdultTorso",
        center=TORSO_CENTER,
        width=TORSO_WIDTH,
        depth=TORSO_DEPTH,
        height=TORSO_HEIGHT,
        face_material=shirt,
        trim_material=shirt,
        top_material=shirt,
        base_z=TORSO_Z0,
    )
    isobuild.box(
        "CustomerAdultArmLeft",
        center=LEFT_ARM_CENTER,
        width=ARM_WIDTH,
        depth=ARM_DEPTH,
        height=ARM_HEIGHT,
        face_material=shirt,
        trim_material=shirt,
        top_material=shirt,
        base_z=ARM_Z0,
    )
    isobuild.box(
        "CustomerAdultArmRight",
        center=RIGHT_ARM_CENTER,
        width=ARM_WIDTH,
        depth=ARM_DEPTH,
        height=ARM_HEIGHT,
        face_material=shirt,
        trim_material=shirt,
        top_material=shirt,
        base_z=ARM_Z0,
    )
    isobuild.box(
        "CustomerAdultHead",
        center=HEAD_CENTER,
        width=HEAD_WIDTH,
        depth=HEAD_DEPTH,
        height=HEAD_HEIGHT,
        face_material=skin,
        trim_material=skin,
        top_material=skin,
        base_z=HEAD_Z0,
    )
    isobuild.box(
        "CustomerAdultHair",
        center=HAIR_CENTER,
        width=HAIR_WIDTH,
        depth=HAIR_DEPTH,
        height=HAIR_HEIGHT,
        face_material=hair,
        trim_material=hair,
        top_material=hair,
        base_z=HAIR_Z0,
    )

    lcol, lrow = LEGS_CENTER
    lhw, lhd = LEGS_WIDTH / 2.0, LEGS_DEPTH / 2.0
    return {
        "base_center": (lcol, lrow, 0.0),
        "top_center": (HAIR_CENTER[0], HAIR_CENTER[1], TOTAL_HEIGHT),
        "base_corner_north": (lcol - lhw, lrow - lhd, 0.0),
        "base_corner_east": (lcol + lhw, lrow - lhd, 0.0),
        "base_corner_south": (lcol + lhw, lrow + lhd, 0.0),
        "base_corner_west": (lcol - lhw, lrow + lhd, 0.0),
    }
