"""Directly-authored 2D revolve shapes: bowls, and anything else that is a
rim ellipse, a tapered body and a foot ellipse stacked in this project's
fixed isometric projection.

This is a *separate*, simpler pipeline from the Blender-based rig the rest
of `tools/isorender/` uses for walls and counters. The Blender rig has no
round/revolve primitive yet, so a vessel like the shop's empty bowl is
authored directly in the same projection instead: two ellipses (the rim a
circle sitting flat on top of the body, the foot a smaller circle sitting
flat on the ground) joined by straight tapering sides, all lit and outlined
to match the rig's output by eye. Runs in plain Python + PIL + numpy — no
Blender dependency, so it can be re-run for any bowl size without opening
Blender.

    python3 tools/isorender/bowl2d.py --rim 0.24 --foot 0.15 --height 0.10 \\
        --name shop_empty_bowl_repro

Every shipped bowl's exact rim/foot/height *and palette* is recorded in
`PRESETS` below, so it can be regenerated with no other arguments:

    python3 tools/isorender/bowl2d.py --preset shop_large_empty_bowl

A palette passed by hand (`--rim`/`--foot`/`--height` free-form, as above)
is not reproducible from this file alone — only a `PRESETS` entry is. Add
one whenever a render's output actually ships.

`build()` also takes two optional, independent parameters. Both default to
`None`, and every existing preset renders byte-identical with both omitted:

- `contents={"base": (r,g,b), "highlight": (r,g,b), "shadow": (r,g,b),
  "flecks": [(r,g,b), ...], "seed": int, "fleck_count": int,
  "fleck_radius_px": float}` — a broken-surface food fill seated flush with
  the rim's top ellipse, inset inside the inner-rim line so that line still
  reads as a ring around the food. `base` is the only required key;
  `highlight`/`shadow` default to `base` (still gradient-lit in the same
  upper-right light direction as the vessel, just monochrome if only `base`
  is given). `flecks`/`seed` are optional — a small, deterministic scatter
  of 1-3 alternate colors so the surface reads as chopped/mixed food rather
  than a poured-in solid; `fleck_count` (default 10) and `fleck_radius_px`
  (default 2.2, final-resolution px) tune how much of it shows. A `PRESETS`
  entry drops this in as e.g.:
  `"contents": {"base": (196, 214, 168), "highlight": (222, 236, 196),
  "shadow": (140, 158, 112), "flecks": [(196, 60, 48), (150, 46, 36)],
  "seed": 7}`.
- `pin_to={"width": int, "height": int, "base_center": (x, y)}` — forces the
  trimmed output onto an exact target pixel grid (typically a previously
  shipped PNG's own dimensions and base-center) instead of whatever the
  alpha-threshold `getbbox()` trim happens to produce, computed directly
  from this render's own known rim-center/foot-center geometry rather than
  by matching alpha edges. Use it to land a second frame of an existing
  vessel (like a filled bowl) on that vessel's already-shipped pixel grid,
  so swapping frames moves nothing on screen. A `PRESETS` entry drops this
  in as e.g. `"pin_to": {"width": 66, "height": 55, "base_center": (32.57,
  41.19)}`.

See `tools/isorender/README.md` for where these projection constants come
from; they are re-derived here only as much as needed to keep this file
self-contained and reproducible.
"""

import argparse
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.join(HERE, "out")

# ---------------------------------------------------------------------------
# Projection constants — shared by the whole rig, not just this script. A
# ground-plane circle of diameter D grid units projects to an ellipse
# D*GRID_PX_3X px wide by that width*SIN_ELEV px tall; a *vertical* rise of
# H grid units (like the bowl's rim sitting above its foot) converts through
# VERTICAL_SCALE instead, because verticals foreshorten by cos(elevation),
# not by the ground-plane sine factor. See this project's CLAUDE.md and
# tools/isorender/README.md for the full derivation; these are the same
# numbers the art director measured off the shipped shop_empty_bowl.png.
# ---------------------------------------------------------------------------
GRID_PX_3X = 267.28636  # px per grid unit on the ground plane, at this project's fixed 3x sprite scale
ELEV_DEG = 38.05  # the rig's camera elevation above the ground plane
SIN_ELEV = 0.616389  # sin(38.05deg) — ground-circle-to-ellipse aspect ratio
COS_ELEV = math.cos(math.radians(ELEV_DEG))  # ~0.78762 — kept as a real cosine, not a
    # second hand-typed literal, so VERTICAL_SCALE's derivation stays checkable in the source
VERTICAL_SCALE = GRID_PX_3X * COS_ELEV  # ~210.4733 px per grid unit of vertical rise

# ---------------------------------------------------------------------------
# Ink + shading. The outline's absolute pixel weight is held constant across
# bowl sizes on purpose (a bigger bowl gets more room between rim and foot,
# not a thicker line) — see this file's module docstring / the brief this
# was written against.
# ---------------------------------------------------------------------------
INK = (34, 34, 34)  # outline core, sampled off the shipped shop_empty_bowl.png's center column
OUTLINE_PX = 1.4  # final-resolution stroke width, independent of bowl size
INNER_RIM_INSET_PX = 3.0  # gap between the outer rim outline and the thin inner-rim
    # line that gives the rim its wall thickness — also held constant across sizes

CONTENTS_INSET_PX = INNER_RIM_INSET_PX + 3.0  # how far inside the outer rim a `contents`
    # fill's own edge sits — deliberately further in than the inner-rim line's ring (inset
    # 3.0px, ~1.4px wide) so that ring reads as a ring around the food, not overlapped by it
DEFAULT_CONTENTS_FLECK_COUNT = 10  # a handful — the fill patch itself is a double-digit-px
    # smudge at the size a bowl actually ships, so more flecks just get lost in the downsample
DEFAULT_CONTENTS_FLECK_RADIUS_PX = 2.2  # final-resolution px, one fleck blob's radius

SUPERSAMPLE = 4  # draw this many times bigger than the final size, then Lanczos back down;
    # that downsample is what turns a hard-edged polygon/ellipse fill into the ~1px
    # antialiased ink feather the shipped bowl has, with no hand-tuned blur radius
MARGIN_PX = 8  # breathing room around the silhouette before trim, at final resolution
TRIM_ALPHA_THRESHOLD = 10  # matches postprocess.py's alpha_bbox convention

OVERLAY_SCALE = 8  # the shipped bowl's own overlay is upscaled 8x for legibility; matched here

#: Warm glazed-earthenware default, sampled off the shipped shop_empty_bowl.png:
#: body mid-tone ~(130, 90, 55), upper-right highlight ~(158, 113, 70). Shadow is
#: this script's own judgement call (a darkened mid-tone) — the shipped bowl's
#: shading fades to flat mid-tone by the foot rather than showing a distinct
#: shadow tone there, so there was no shipped value to sample.
DEFAULT_PALETTE = {
    "mid": (130, 90, 55),
    "highlight": (158, 113, 70),
    "shadow": (92, 61, 38),
}

#: Every shipped (or accepted-as-shipped) bowl, with the *exact* rim/foot/
#: height/palette it was rendered with — the only way `--rim`/`--foot`/
#: `--height`/`--mid` free-form flags don't leave a render unreproducible
#: is to write the values down here once the render is accepted.
PRESETS = {
    "shop_empty_bowl": {
        # The small bowl's own generator (PR #86) was never committed, so
        # this is a *reproduction*, not the shipped PNG byte-for-byte: it
        # comes out 67x56 vs. the shipped 66x55 (1px rounding) with softer
        # shading. Accepted by the art director because the difference
        # washes out at the 1x size this sprite actually ships at — see
        # commit 5a239eb. Uses this script's own DEFAULT_PALETTE, since
        # there was no shipped generator to match a palette against.
        "rim": 0.24,
        "foot": 0.15,
        "height": 0.10,
        "palette": dict(DEFAULT_PALETTE),
    },
    "shop_large_empty_bowl": {
        # The exact palette shop_large_empty_bowl.png (in
        # Resources/Assets.xcassets/shop/) was rendered with — "a slightly
        # richer glaze tone" than the small bowl per commit 5a239eb, spelled
        # out here so that description is no longer the only record of it.
        "rim": 0.38,
        "foot": 0.24,
        "height": 0.16,
        "palette": {
            "mid": (140, 88, 50),
            "highlight": (172, 116, 68),
            "shadow": (98, 58, 34),
        },
    },
    "shop_empty_pot": {
        # Slot 2 (the prep table's high-row end) — a cooking pot, not a
        # third bowl. Rim/foot are close together (1.15:1, vs. the bowls'
        # ~1.6:1) for straight sides, and height/width is 0.8 vs. the
        # bowls' ~0.42, so it reads tall and cylindrical next to their
        # wide, flared silhouettes. Rim 0.30 keeps it narrower than
        # shop_large_empty_bowl (0.38, the widest prop on the table) with
        # clear air either side of its 0.583-grid-unit slot.
        #
        # Palette was originally the same warm glazed-earthenware family as
        # both bowls, per the art director's set-coherence call — the user
        # overrode that on review (it didn't read as a pot) and asked for
        # stainless steel instead: cool grey body, near-white highlight,
        # blue-grey shadow. The ink outline stays warm (INK is shared by
        # every vessel, untouched here). Note this script's shading model
        # (see `build()`) is a linear diffuse ramp across the whole
        # rim-to-foot height, not a true specular term with a falloff
        # curve — so "near-white highlight" below is an approximation of a
        # tight specular band, not the real thing; it can only push the
        # existing broad gradient toward metal via color choice alone.
        "rim": 0.30,
        "foot": 0.26,
        "height": 0.24,
        "palette": {
            "mid": (140, 146, 152),        # cool neutral grey body, faint blue cast
            "highlight": (238, 241, 243),  # near-white specular
            "shadow": (58, 68, 82),        # blue-grey shadow side, cooler & darker than mid
        },
    },
    "shop_daejeop_bowl": {
        # A large ceramic mixing/serving bowl (대접) for the shop's slot 2,
        # replacing shop_empty_pot there (that preset and its art stay in
        # the repo, just unused). Third vessel in the warm glazed-
        # earthenware family on purpose, but it must read as *deeper and
        # steeper-walled* than a scaled-up shop_large_empty_bowl, not just
        # bigger — a mixing bowl, not a serving plate.
        #
        # Both shipped bowls sit at rim:foot ~1.6 and height:rim ~0.42 (a
        # shallow, flared profile). This one is rim:foot 1.41 (0.45/0.32 —
        # less taper, steeper wall) and height:rim 0.53 (0.24/0.45 —
        # noticeably deeper). Rim 0.45 is the widest vessel in the set on
        # purpose, the visible size step up from 0.38; still clears the
        # 0.583-grid-unit slot spacing against shop_large_empty_bowl in
        # slot 1 (0.19 + 0.225 = 0.415 combined half-width, well under
        # 0.583).
        #
        # Palette is the same brown family but deliberately not the
        # midpoint of the two shipped bowls' values (which would read as a
        # straight re-scale) — darker and a shade more saturated, since a
        # bigger mixing vessel reads better with a richer, less "clean"
        # glaze than the two shallow serving bowls. mid (122,76,42) is
        # darker than both shop_empty_bowl (130,90,55) and
        # shop_large_empty_bowl (140,88,50); highlight/shadow follow the
        # same darker-and-richer direction.
        "rim": 0.45,
        "foot": 0.32,
        "height": 0.24,
        "palette": {
            "mid": (122, 76, 42),
            "highlight": (162, 108, 58),
            "shadow": (76, 46, 24),
        },
    },
    "shop_geotjeori_bowl": {
        # The small prep-table bowl's second, "filled" frame — swapped in at the
        # cook gauge's halfway point and back out to shop_empty_bowl on completion
        # (ShopNode's cook-progress flow). Same vessel as shop_empty_bowl (rim/
        # foot/height/palette identical, copied from that preset rather than
        # re-typed) because it is the same physical bowl with food added, not a
        # new prop — only `contents` differs.
        "rim": 0.24,
        "foot": 0.15,
        "height": 0.10,
        "palette": dict(DEFAULT_PALETTE),
        # 겉절이 (fresh spring-cabbage kimchi, lightly seasoned) — pale green
        # cabbage carrying a threaded red-pepper seasoning, not the deep uniform
        # red of aged kimchi. base/highlight/shadow are a green ramp so the
        # vessel's own upper-right diffuse light still models the surface (same
        # gradient the vessel body uses — see `_apply_contents`); shadow is
        # noticeably darker+cooler than base (140,158,112 vs. 196,214,168) so
        # the lower-left corner of the patch reads as a leaf-shadow break rather
        # than a flat-lit disc. flecks carries the red pepper as a *minority*
        # accent color, not a fill: two red tones (fresh-looking (196,60,48) and
        # a darker (150,46,36), so the pepper itself isn't flat either) plus a
        # third, darker green (90,120,60) so some flecks read as chopped leaf
        # rather than only pepper — three fleck colors keep any single one from
        # dominating the ~10-fleck scatter. fleck_count/fleck_radius left at
        # this file's defaults (10 / 2.2px) — the brief warned the whole patch
        # is only a handful of px at ship size, so more flecks would just
        # smear together under the Lanczos downsample rather than read as
        # texture. seed 7 fixed so this preset reproduces byte-identical; no
        # significance to the number beyond "picked once and recorded."
        "contents": {
            "base": (196, 214, 168),
            "highlight": (222, 236, 196),
            "shadow": (140, 158, 112),
            "flecks": [(196, 60, 48), (150, 46, 36), (90, 120, 60)],
            "seed": 7,
        },
    },
    "shop_bomdong_kimchi_bowl": {
        # The large bowl's second, "filled" frame — the shop's menu 1, 봄동김치
        # (seasoned spring-cabbage kimchi). Same vessel as shop_large_empty_bowl
        # (rim/foot/height/palette identical, copied from that preset rather than
        # re-typed) because it is the same physical bowl with food added, not a
        # new prop — only `contents` differs. Following the same precedent as
        # shop_geotjeori_bowl on shop_empty_bowl.
        "rim": 0.38,
        "foot": 0.24,
        "height": 0.16,
        "palette": {
            "mid": (140, 88, 50),
            "highlight": (172, 116, 68),
            "shadow": (98, 58, 34),
        },
        # 봄동김치 is fully coated in red gochugaru seasoning, unlike geotjeori's
        # lightly-seasoned pale cabbage — so the balance is inverted on purpose:
        # here the *base* carries the red-orange gochugaru tone and the *flecks*
        # are the minority color, showing green cabbage leaf peeking through the
        # coating. base/highlight/shadow are a red-orange-brown ramp, still lit
        # by the same upper-right diffuse gradient as the vessel (see
        # `_apply_contents`); shadow (108,34,20) is noticeably darker+cooler than
        # base (168,58,34) so the lower-left corner of the patch reads as a
        # break in the coating rather than a flat-lit disc, matching every other
        # preset's gradient. flecks carries two green leaf tones — a lighter
        # (86,120,54) and a darker (54,86,38), so the cabbage itself isn't flat
        # either — deliberately the opposite arrangement of shop_geotjeori_bowl
        # (green base / red flecks), which is exactly what makes the two dishes
        # read as different at a glance rather than as re-colors of one texture.
        # fleck_count bumped from the file default (10) to 16: this bowl's rim
        # (0.38) is ~1.6x geotjeori's (0.24), so the fill patch covers roughly
        # 2.5x the area at ship size — 10 flecks read sparse on a patch that
        # much bigger, 16 keeps the leaf-through-coating texture visible without
        # the flecks smearing together under the Lanczos downsample. seed 11
        # fixed so this preset reproduces byte-identical; picked only to differ
        # from geotjeori's 7 so the scatter pattern itself doesn't coincidentally
        # match, no other significance.
        "contents": {
            "base": (168, 58, 34),
            "highlight": (200, 88, 52),
            "shadow": (108, 34, 20),
            "flecks": [(86, 120, 54), (54, 86, 38)],
            "seed": 11,
            "fleck_count": 16,
        },
    },
    "shop_bomdong_bibimbap_bowl": {
        # The daejeop (mixing) bowl's second, "filled" frame — the shop's menu 2,
        # 봄동비빔밥 (spring-cabbage bibimbap). Same vessel as shop_daejeop_bowl
        # (rim/foot/height/palette identical, copied from that preset rather than
        # re-typed) because it is the same physical bowl with food added, not a
        # new prop — only `contents` differs. Following the same precedent as
        # shop_geotjeori_bowl on shop_empty_bowl and shop_bomdong_kimchi_bowl on
        # shop_large_empty_bowl.
        "rim": 0.45,
        "foot": 0.32,
        "height": 0.24,
        "palette": {
            "mid": (122, 76, 42),
            "highlight": (162, 108, 58),
            "shadow": (76, 46, 24),
        },
        # Both existing filled bowls are single-color coatings (a red kimchi
        # coating, a pale cabbage) told apart mainly by base hue. Bibimbap is a
        # genuinely mixed dish — rice base with several toppings stirred through
        # — so it needs a third hue family, not another red-or-green base, to
        # read as a different dish at a glance rather than a recolor: warm
        # cooked-rice base/highlight/shadow ramp (still the same upper-right
        # diffuse gradient every vessel/content fill uses, see
        # `_apply_contents`), carrying three minority fleck colors instead of
        # the usual one or two — green bomdong leaf, red gochujang, and a
        # yellow egg-yolk accent — so the scatter itself reads as "mixed toppings"
        # rather than a single seasoning. Fleck hues were chosen to stay clear
        # of the other two bowls' own fleck/base colors at a glance: this
        # green (80,116,50) sits between geotjeori's base green and kimchi's
        # fleck greens without matching either; this red (196,68,40) is a
        # brighter, more orange gochujang red than kimchi's darker coating
        # red/gochugaru base, so it doesn't get mistaken for a kimchi smear.
        # fleck_count 22: this bowl's rim (0.45) is the widest in the set —
        # ~1.4x shop_bomdong_kimchi_bowl's 0.38, so its fill patch covers
        # roughly 1.4x the area — scaled up from that bowl's 16 by the same
        # area-ratio reasoning used there (16 * (0.45/0.38)^2 ~= 22.4). Radius
        # left at the file default (2.2px) like every other preset — only
        # count scales with patch area, not fleck size. seed 19 fixed so this
        # preset reproduces byte-identical; picked only to differ from
        # geotjeori's 7 and kimchi's 11, no other significance.
        "contents": {
            "base": (218, 190, 142),
            "highlight": (236, 214, 168),
            "shadow": (168, 138, 96),
            "flecks": [(80, 116, 50), (196, 68, 40), (230, 172, 44)],
            "seed": 19,
            "fleck_count": 22,
        },
    },
}


def _ellipse_extent(diameter_units):
    """A ground-plane circle of this diameter, projected: (width_px, height_px)."""
    width = diameter_units * GRID_PX_3X
    return width, width * SIN_ELEV


def _ring(mask, radius_px):
    """A thin ring straddling `mask`'s boundary, `radius_px` px to each side —
    used for both the outer silhouette outline and the inner rim line, so
    both are drawn as "stroke centered on an edge" rather than hand-traced
    arcs and lines."""
    r = max(1, round(radius_px))
    k = 2 * r + 1
    dilated = mask.filter(ImageFilter.MaxFilter(k))
    eroded = mask.filter(ImageFilter.MinFilter(k))
    ring = np.array(dilated).astype(np.int16) - np.array(eroded).astype(np.int16)
    return Image.fromarray(np.clip(ring, 0, 255).astype(np.uint8), "L")


def _apply_contents(canvas, contents, cx, rim_cy, rim_w, rim_h, ss, S, highlight_amt, shadow_amt, body_alpha):
    """Composite a broken-surface food fill onto `canvas`, seated flush with the rim's top
    ellipse and inset inside the inner-rim line. Called only when `contents` is truthy, after
    the vessel's own gradient/silhouette are already final — so an omitted `contents` leaves
    `canvas` (and therefore the whole render) untouched. See module docstring for the dict
    schema. Alpha is clamped to both the inset fill ellipse and the vessel's own opaque
    silhouette (`body_alpha`), so this can never add a visible pixel outside the existing body
    or past the inner-rim inset, regardless of how the fill/flecks are drawn."""
    inset = CONTENTS_INSET_PX
    w = rim_w - inset * 2
    h = rim_h - inset * 2 * SIN_ELEV
    if w <= 0 or h <= 0:
        return canvas  # vessel too small for an inset content patch at all — skip, don't error

    bbox = (S(cx - w / 2), S(rim_cy - h / 2), S(cx + w / 2), S(rim_cy + h / 2))
    fill_mask = Image.new("L", canvas.size, 0)
    ImageDraw.Draw(fill_mask).ellipse(bbox, fill=255)
    fill_mask_arr = np.array(fill_mask)

    base = np.array(contents["base"], dtype=np.float32)
    hi = np.array(contents.get("highlight", contents["base"]), dtype=np.float32)
    sh = np.array(contents.get("shadow", contents["base"]), dtype=np.float32)
    # Same linear diffuse ramp as the vessel's own gradient, in the same upper-right light
    # direction (highlight_amt/shadow_amt are the body's own gradient fields) — a shape-
    # vocabulary addition, not a new lighting concept.
    color = (
        base[None, None, :]
        + (hi - base)[None, None, :] * highlight_amt[..., None]
        + (sh - base)[None, None, :] * shadow_amt[..., None]
    )
    color = np.clip(color, 0, 255).astype(np.uint8)

    alpha = np.minimum(fill_mask_arr, body_alpha).astype(np.uint8)
    content_layer = Image.fromarray(np.dstack([color, alpha]), "RGBA")

    flecks = contents.get("flecks") or []
    if flecks:
        rng = np.random.RandomState(contents.get("seed", 0))
        count = contents.get("fleck_count", DEFAULT_CONTENTS_FLECK_COUNT)
        radius = S(contents.get("fleck_radius_px", DEFAULT_CONTENTS_FLECK_RADIUS_PX))
        fleck_draw = ImageDraw.Draw(content_layer)
        for _ in range(count):
            theta = rng.uniform(0, 2 * math.pi)
            r = math.sqrt(rng.uniform(0, 1)) * 0.72  # keep flecks off the patch's own edge
            fx = cx + r * (w / 2) * math.cos(theta)
            fy = rim_cy + r * (h / 2) * math.sin(theta)
            fr, fg, fb = flecks[rng.randint(0, len(flecks))]
            fleck_draw.ellipse(
                [S(fx) - radius, S(fy) - radius, S(fx) + radius, S(fy) + radius],
                fill=(int(fr), int(fg), int(fb), 255),
            )
        # Flecks are drawn as hard circles, not alpha-blended — reclamp in case one bled a
        # pixel past the inset ellipse at a very small vessel size, so containment is exact
        # regardless of fleck placement rather than merely "usually inside."
        c_alpha = np.array(content_layer.split()[3])
        clamped = np.minimum(c_alpha, np.minimum(fill_mask_arr, body_alpha))
        content_layer.putalpha(Image.fromarray(clamped.astype(np.uint8), "L"))

    return Image.alpha_composite(canvas, content_layer)


def _pin_trim(final, cx, rim_cy, foot_cy, pin_to):
    """Re-crop `final` (the full, untrimmed render) onto an exact target pixel grid — width,
    height and base_center — computed directly from the known cx/foot_cy geometry, instead of
    from `getbbox()`'s alpha-threshold trim. For aligning a second frame of an existing vessel
    onto a previously shipped PNG's own pixel grid. Returns (trimmed, base_center, top_center,
    clipped), where `clipped` is True if the target box excludes any pixel `final` actually
    considers non-transparent (TRIM_ALPHA_THRESHOLD, the same convention as the normal trim) —
    i.e. forcing this box would cut off real silhouette, not just margin."""
    target_w = pin_to["width"]
    target_h = pin_to["height"]
    target_bx, target_by = pin_to["base_center"]

    ox = round(cx - target_bx)
    oy = round(foot_cy - target_by)
    target_box = (ox, oy, ox + target_w, oy + target_h)

    natural_box = final.split()[3].point(lambda v: 255 if v >= TRIM_ALPHA_THRESHOLD else 0).getbbox()
    clipped = natural_box is not None and (
        natural_box[0] < target_box[0]
        or natural_box[1] < target_box[1]
        or natural_box[2] > target_box[2]
        or natural_box[3] > target_box[3]
    )
    if clipped:
        print(
            f"WARNING: pin_to clips real pixels — natural alpha bbox {natural_box} "
            f"vs. pin_to target box {target_box}"
        )

    trimmed = Image.new("RGBA", (target_w, target_h), (0, 0, 0, 0))
    # Overlap between the target box and final's actual canvas — a target box that reaches
    # past final's own edges pads with transparent pixels instead of erroring.
    src_box = (
        max(target_box[0], 0),
        max(target_box[1], 0),
        min(target_box[2], final.width),
        min(target_box[3], final.height),
    )
    if src_box[0] < src_box[2] and src_box[1] < src_box[3]:
        region = final.crop(src_box)
        paste_at = (src_box[0] - target_box[0], src_box[1] - target_box[1])
        trimmed.paste(region, paste_at)

    base_center = (round(cx - ox, 2), round(foot_cy - oy, 2))
    top_center = (round(cx - ox, 2), round(rim_cy - oy, 2))
    return trimmed, base_center, top_center, clipped


def build(rim, foot, height, name, palette=None, out_dir=OUT_DIR, contents=None, pin_to=None):
    """Render a bowl: rim ellipse (diameter `rim` grid units) tapering down
    to a foot ellipse (diameter `foot`), `height` grid units of rise between
    them. Writes `<name>.png` (trimmed) and `<name>.overlay.png`, and returns
    the measurement dict also printed to stdout."""
    pal = dict(DEFAULT_PALETTE)
    if palette:
        pal.update(palette)

    rim_w, rim_h = _ellipse_extent(rim)
    foot_w, foot_h = _ellipse_extent(foot)
    rise_px = height * VERTICAL_SCALE

    half_w = max(rim_w, foot_w) / 2
    canvas_w = math.ceil(half_w * 2 + MARGIN_PX * 2)
    canvas_h = math.ceil(rim_h / 2 + rise_px + foot_h / 2 + MARGIN_PX * 2)

    cx = canvas_w / 2
    rim_cy = MARGIN_PX + rim_h / 2
    foot_cy = rim_cy + rise_px

    ss = SUPERSAMPLE
    S = lambda v: v * ss

    def ellipse_bbox(cy, w, h):
        return (S(cx - w / 2), S(cy - h / 2), S(cx + w / 2), S(cy + h / 2))

    canvas = Image.new("RGBA", (round(canvas_w * ss), round(canvas_h * ss)), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    opaque = (255, 255, 255, 255)

    # Body silhouette = rim cap (full ellipse) + tapering trapezoid sides +
    # foot ellipse (full — its top half re-fills space the trapezoid already
    # covers, its bottom half is the visible front curve of the foot).
    draw.ellipse(ellipse_bbox(rim_cy, rim_w, rim_h), fill=opaque)
    draw.polygon(
        [
            (S(cx - rim_w / 2), S(rim_cy)),
            (S(cx + rim_w / 2), S(rim_cy)),
            (S(cx + foot_w / 2), S(foot_cy)),
            (S(cx - foot_w / 2), S(foot_cy)),
        ],
        fill=opaque,
    )
    draw.ellipse(ellipse_bbox(foot_cy, foot_w, foot_h), fill=opaque)

    silhouette = canvas.split()[3].point(lambda v: 255 if v >= 128 else 0)

    # Warm gradient, lit from the upper right: brightest at the rim's right
    # side, fading to flat mid-tone by the foot (matching the shipped bowl,
    # which shows no shading gradient left at its base), with a weaker,
    # symmetric darkening on the rim's left side standing in for shadow.
    ys, xs = np.mgrid[0 : canvas.height, 0 : canvas.width]
    xf, yf = xs / ss, ys / ss
    horiz = np.clip((xf - cx) / (rim_w / 2), -1, 1)
    vert = np.clip(1.0 - (yf - rim_cy) / max(rise_px, 1e-6), 0, 1)
    highlight_amt = np.clip(horiz, 0, 1) * vert
    shadow_amt = np.clip(-horiz, 0, 1) * vert * 0.6

    mid = np.array(pal["mid"], dtype=np.float32)
    hi = np.array(pal["highlight"], dtype=np.float32)
    sh = np.array(pal["shadow"], dtype=np.float32)
    color = (
        mid[None, None, :]
        + (hi - mid)[None, None, :] * highlight_amt[..., None]
        + (sh - mid)[None, None, :] * shadow_amt[..., None]
    )
    color = np.clip(color, 0, 255).astype(np.uint8)

    body_alpha = np.array(canvas.split()[3])
    rgba = np.dstack([color, body_alpha])
    canvas = Image.fromarray(rgba, "RGBA")

    if contents:
        canvas = _apply_contents(
            canvas, contents, cx, rim_cy, rim_w, rim_h, ss, S, highlight_amt, shadow_amt, body_alpha
        )

    # Outer silhouette outline.
    outer_ring = _ring(silhouette, OUTLINE_PX / 2 * ss)
    # Inner rim line: a thin ellipse inset from the outer rim, full (both
    # near and far arcs visible — it sits entirely inside the already-solid
    # rim cap, same reasoning as the foot ellipse above).
    inset = INNER_RIM_INSET_PX
    inner_rim_mask = Image.new("L", canvas.size, 0)
    ImageDraw.Draw(inner_rim_mask).ellipse(
        ellipse_bbox(rim_cy, rim_w - inset * 2, rim_h - inset * 2 * SIN_ELEV), fill=255
    )
    inner_ring = _ring(inner_rim_mask, OUTLINE_PX / 2 * ss)

    ink_layer = Image.new("RGBA", canvas.size, INK + (0,))
    ink_alpha = np.array(outer_ring).astype(np.int16) + np.array(inner_ring).astype(np.int16)
    ink_layer.putalpha(Image.fromarray(np.clip(ink_alpha, 0, 255).astype(np.uint8), "L"))

    composed = Image.alpha_composite(canvas, ink_layer)
    final = composed.resize((round(canvas_w), round(canvas_h)), Image.LANCZOS)

    if pin_to:
        trimmed, base_center, top_center, _clipped = _pin_trim(final, cx, rim_cy, foot_cy, pin_to)
    else:
        box = final.split()[3].point(lambda v: 255 if v >= TRIM_ALPHA_THRESHOLD else 0).getbbox()
        trimmed = final.crop(box)

        ox, oy = box[0], box[1]
        base_center = (round(cx - ox, 2), round(foot_cy - oy, 2))
        top_center = (round(cx - ox, 2), round(rim_cy - oy, 2))

    os.makedirs(out_dir, exist_ok=True)
    png_path = os.path.join(out_dir, f"{name}.png")
    overlay_path = os.path.join(out_dir, f"{name}.overlay.png")
    trimmed.save(png_path)
    _save_overlay(trimmed, base_center, top_center, overlay_path)

    width, height_px = trimmed.size
    bx, by = base_center
    measurements = {
        "name": name,
        "width": width,
        "height": height_px,
        "base_center": base_center,
        "top_center": top_center,
        "anchor_fraction_x": bx / width,
        "anchor_fraction_y_from_bottom": 1 - by / height_px,
    }
    _print_table(measurements, rim, foot, height)
    return measurements


def _save_overlay(trimmed, base_center, top_center, path):
    big = trimmed.resize(
        (trimmed.width * OVERLAY_SCALE, trimmed.height * OVERLAY_SCALE), Image.NEAREST
    )
    draw = ImageDraw.Draw(big)
    draw.rectangle([0, 0, big.width - 1, big.height - 1], outline=(0, 160, 255, 255))
    for label, (x, y), color in [
        ("base_center", base_center, (255, 0, 80, 255)),
        ("top_center", top_center, (60, 90, 255, 255)),
    ]:
        bx, by = x * OVERLAY_SCALE, y * OVERLAY_SCALE
        draw.line([(bx - 10, by), (bx + 10, by)], fill=color, width=2)
        draw.line([(bx, by - 10), (bx, by + 10)], fill=color, width=2)
        draw.text((bx + 8, by - 6), f"{label} ({x}, {y})", fill=color)
    draw.text(
        (6, 4),
        f"size {trimmed.width}x{trimmed.height} px (3x scale)",
        fill=(20, 20, 20, 255),
    )
    big.save(path)


def _print_table(m, rim, foot, height):
    bx, by = m["base_center"]
    tx, ty = m["top_center"]
    print(f"bowl: rim {rim} / foot {foot} / height {height} grid units")
    print(f"{'trimmed width':<28}{m['width']}")
    print(f"{'trimmed height':<28}{m['height']}")
    print(f"{'base center (x, y)':<28}({bx}, {by})   (top-left origin, y down)")
    print(f"{'top center (x, y)':<28}({tx}, {ty})   (top-left origin, y down)")
    print(f"{'anchor fraction x':<28}{m['anchor_fraction_x']:.5f}")
    print(
        f"{'anchor fraction y':<28}{m['anchor_fraction_y_from_bottom']:.5f}"
        f"   (from the bottom; raw top-left y = {by})"
    )


def _parse_rgb(text):
    parts = [int(p) for p in text.split(",")]
    if len(parts) != 3:
        raise argparse.ArgumentTypeError("expected R,G,B")
    return tuple(parts)


def _parse_pin_to(text):
    parts = [float(p) for p in text.split(",")]
    if len(parts) != 4:
        raise argparse.ArgumentTypeError("expected WIDTH,HEIGHT,BASE_X,BASE_Y")
    w, h, bx, by = parts
    return {"width": int(w), "height": int(h), "base_center": (bx, by)}


def main():
    parser = argparse.ArgumentParser(prog="bowl2d.py")
    parser.add_argument(
        "--preset", choices=sorted(PRESETS), help="a named PRESETS entry — records rim/foot/height/palette"
    )
    parser.add_argument("--rim", type=float, help="rim diameter, grid units (overrides --preset's)")
    parser.add_argument("--foot", type=float, help="foot diameter, grid units (overrides --preset's)")
    parser.add_argument("--height", type=float, help="rim-to-foot rise, grid units (overrides --preset's)")
    parser.add_argument("--name", help="output basename under tools/isorender/out/ (defaults to --preset)")
    parser.add_argument("--mid", type=_parse_rgb, help="body mid-tone, R,G,B (overrides --preset's)")
    parser.add_argument("--highlight", type=_parse_rgb, help="upper-right highlight, R,G,B (overrides --preset's)")
    parser.add_argument("--shadow", type=_parse_rgb, help="lower-left shadow, R,G,B (overrides --preset's)")
    parser.add_argument("--out-dir", default=OUT_DIR)
    parser.add_argument(
        "--pin-to",
        type=_parse_pin_to,
        help="WIDTH,HEIGHT,BASE_X,BASE_Y — override/force pin_to without adding a PRESETS entry, "
        "for a one-off comparison render pinned to another asset's shipped pixel grid",
    )
    args = parser.parse_args()

    if args.preset:
        spec = PRESETS[args.preset]
        rim = spec["rim"] if args.rim is None else args.rim
        foot = spec["foot"] if args.foot is None else args.foot
        height = spec["height"] if args.height is None else args.height
        name = args.name or args.preset
        palette = dict(spec["palette"])
        contents = spec.get("contents")
        pin_to = spec.get("pin_to")
    else:
        if args.rim is None or args.foot is None or args.height is None or not args.name:
            parser.error("either --preset, or all of --rim/--foot/--height/--name, are required")
        rim, foot, height, name = args.rim, args.foot, args.height, args.name
        palette = {}
        contents = None
        pin_to = None

    if args.mid:
        palette["mid"] = args.mid
    if args.highlight:
        palette["highlight"] = args.highlight
    if args.shadow:
        palette["shadow"] = args.shadow

    if args.pin_to is not None:
        pin_to = args.pin_to

    build(rim, foot, height, name, palette=palette or None, out_dir=args.out_dir, contents=contents, pin_to=pin_to)


if __name__ == "__main__":
    main()
