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


def build(rim, foot, height, name, palette=None, out_dir=OUT_DIR):
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


def main():
    parser = argparse.ArgumentParser(prog="bowl2d.py")
    parser.add_argument("--rim", type=float, required=True, help="rim diameter, grid units")
    parser.add_argument("--foot", type=float, required=True, help="foot diameter, grid units")
    parser.add_argument("--height", type=float, required=True, help="rim-to-foot rise, grid units")
    parser.add_argument("--name", required=True, help="output basename under tools/isorender/out/")
    parser.add_argument("--mid", type=_parse_rgb, help="body mid-tone, R,G,B")
    parser.add_argument("--highlight", type=_parse_rgb, help="upper-right highlight, R,G,B")
    parser.add_argument("--shadow", type=_parse_rgb, help="lower-left shadow, R,G,B")
    parser.add_argument("--out-dir", default=OUT_DIR)
    args = parser.parse_args()

    palette = {}
    if args.mid:
        palette["mid"] = args.mid
    if args.highlight:
        palette["highlight"] = args.highlight
    if args.shadow:
        palette["shadow"] = args.shadow

    build(args.rim, args.foot, args.height, args.name, palette=palette or None, out_dir=args.out_dir)


if __name__ == "__main__":
    main()
