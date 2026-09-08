"""Trim a render, and report its geometry as plain numbers.

Runs in normal Python (PIL), not in Blender. Reads the PNG and the
`.markers.json` the rig wrote beside it, and produces:

  * `<asset>.png`          — alpha-trimmed, ready to drop into an imageset
  * `<asset>.overlay.png`  — the same image with what was measured drawn on it
  * a measurement table on stdout, in the format
    `.claude/agents/2.5d-game-designer.md` hands to `ios-developer`

The numbers come from the camera matrix by way of `markers.json`, not from
inspecting pixels. Antialiasing spreads a rendered edge over about a pixel, so
a measured alpha bounding box and the true geometry disagree by ~1 px at 3x;
the projected markers do not disagree with anything.

    python3 tools/isorender/postprocess.py --asset wall_shop_left
"""

import argparse
import json
import os

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))

#: Faces of a wall, in the order the measurement table wants them.
WALL_FACE_MARKERS = [
    ("top-left", "face_top_start"),
    ("top-right", "face_top_end"),
    ("bottom-left", "face_bottom_start"),
    ("bottom-right", "face_bottom_end"),
]

#: A free-standing prop's (`isobuild.prop_table`) base footprint corners, in
#: the order the measurement table prints them. Not part of the anchor
#: calculation the way the wall's face corners are — printed as extra plain
#: numbers so a footprint's clearance against the cell edge or a neighbouring
#: cell can be checked from the numbers alone, without eyeballing the overlay.
PROP_CORNER_MARKERS = [
    ("north", "base_corner_north"),
    ("east", "base_corner_east"),
    ("south", "base_corner_south"),
    ("west", "base_corner_west"),
]


def alpha_bbox(image, threshold):
    """The bounding box of everything at least `threshold` opaque."""
    alpha = image.split()[3]
    mask = alpha.point(lambda value: 255 if value >= threshold else 0)
    return mask.getbbox()


def load(asset, out_dir, scale):
    png = os.path.join(out_dir, f"{asset}@{int(scale)}x.png")
    markers = os.path.join(out_dir, f"{asset}.markers.json")
    if not os.path.exists(png):
        raise SystemExit(f"no render at {png} — run render.sh first")
    with open(markers) as handle:
        return Image.open(png).convert("RGBA"), json.load(handle)


def shift_markers(report, origin):
    """Marker pixels are in canvas coordinates; the trimmed sprite's origin
    moves, so shift them to match what ships."""
    left, top = origin
    return {
        name: (round(point["x"] - left, 2), round(point["y"] - top, 2))
        for name, point in report["markers"].items()
    }


def wall_table(image, points):
    """The wall measurement table: trimmed size, the four face corners, the
    corner that sits on the tile vertex, and the face slope."""
    width, height = image.size
    corners = {label: points[name] for label, name in WALL_FACE_MARKERS if name in points}
    if len(corners) < 4:
        return None

    (x0, y0), (x1, y1) = corners["bottom-left"], corners["bottom-right"]
    slope = (y1 - y0) / (x1 - x0)

    lines = [
        f"{'trimmed width':<22}{width}",
        f"{'trimmed height':<22}{height}",
    ]
    for label, _ in WALL_FACE_MARKERS:
        x, y = corners[label]
        lines.append(f"{'face ' + label:<22}({x}, {y})")
    lines += [
        f"{'anchor corner':<22}bottom-left, on the tile vertex",
        f"{'anchor (x, y)':<22}({x0}, {y0})",
        f"{'anchor fraction x':<22}{x0 / width:.5f}",
        f"{'anchor fraction y':<22}{1 - y0 / height:.5f}   (from the bottom)",
        f"{'depth vector':<22}({round(x1 - x0, 2)}, {round(y1 - y0, 2)})",
        f"{'face slope':<22}{slope:.5f}",
    ]
    return "\n".join(lines)


def prop_table(image, points):
    """The free-standing-prop measurement table: trimmed size, the base
    anchor (ported from the portable skill's `base_center` branch, which
    solved this first — see
    `~/.claude/skills/2.5d-game-asset-designer/scripts/postprocess.py`), plus
    the footprint corners and the top-surface anchor as extra plain-number
    lines, since the asset designer needs those to check footprint clearance
    without eyeballing the overlay.
    """
    if "base_center" not in points:
        return None
    width, height = image.size
    x, y = points["base_center"]

    lines = [
        f"{'trimmed width':<22}{width}",
        f"{'trimmed height':<22}{height}",
        f"{'base center (x, y)':<22}({x}, {y})",
        f"{'anchor fraction x':<22}{x / width:.5f}",
        f"{'anchor fraction y':<22}{1 - y / height:.5f}   (from the bottom)",
    ]
    for label, name in PROP_CORNER_MARKERS:
        if name not in points:
            continue
        cx, cy = points[name]
        lines.append(f"{'base corner ' + label:<22}({cx}, {cy})")
    if "top_center" in points:
        tx, ty = points["top_center"]
        lines.append(f"{'top center (x, y)':<22}({tx}, {ty})")
    return "\n".join(lines)


#: Prop markers drawn on the overlay beyond the wall's face corners: the
#: ground anchor, footprint corners, and the top-surface anchor a later prop
#: (e.g. a bowl on this table) will be positioned from.
PROP_OVERLAY_MARKERS = [("base", "base_center")] + PROP_CORNER_MARKERS + [("top", "top_center")]


def overlay(image, points, path):
    """Draw the measured box and corners onto a copy, so a human can see that
    the numbers describe the thing they think they describe."""
    canvas = image.copy()
    draw = ImageDraw.Draw(canvas)
    draw.rectangle([0, 0, canvas.width - 1, canvas.height - 1], outline=(0, 160, 255, 255))
    for label, name in WALL_FACE_MARKERS + PROP_OVERLAY_MARKERS:
        if name not in points:
            continue
        x, y = points[name]
        draw.line([(x - 8, y), (x + 8, y)], fill=(255, 0, 80, 255))
        draw.line([(x, y - 8), (x, y + 8)], fill=(255, 0, 80, 255))
        draw.text((x + 6, y + 4), label, fill=(255, 0, 80, 255))
    canvas.save(path)


def verify_calibration(image, report, threshold):
    """The rig's own check: one flat cell must measure exactly one tile."""
    points = report["markers"]
    measured_width = points["tile_east"]["x"] - points["tile_west"]["x"]
    measured_height = points["tile_south"]["y"] - points["tile_north"]["y"]
    expected_width = report["tile_width_px"]
    expected_height = report["tile_height_px"]
    box = alpha_bbox(image, threshold)

    print("projected width   %.3f  expected %.3f" % (measured_width, expected_width))
    print("projected height  %.3f  expected %.3f" % (measured_height, expected_height))
    print("rendered bbox     %d x %d (antialiased edge, expect within 1 px)"
          % (box[2] - box[0], box[3] - box[1]))

    ok = (abs(measured_width - expected_width) < 0.01
          and abs(measured_height - expected_height) < 0.01
          and abs((box[2] - box[0]) - expected_width) <= 2
          and abs((box[3] - box[1]) - expected_height) <= 2)
    print("CALIBRATION", "PASS" if ok else "FAIL")
    raise SystemExit(0 if ok else 1)


def main():
    parser = argparse.ArgumentParser(prog="postprocess.py")
    parser.add_argument("--asset", required=True)
    parser.add_argument("--scale", type=float, default=3.0)
    parser.add_argument("--out", default=os.path.join(HERE, "out"))
    parser.add_argument("--threshold", type=int, default=8,
                        help="alpha at or above which a pixel counts as content")
    args = parser.parse_args()

    image, report = load(args.asset, args.out, args.scale)

    if args.asset == "calibrate":
        verify_calibration(image, report, 128)

    box = alpha_bbox(image, args.threshold)
    trimmed = image.crop(box)
    points = shift_markers(report, (box[0], box[1]))

    trimmed_path = os.path.join(args.out, f"{args.asset}.png")
    overlay_path = os.path.join(args.out, f"{args.asset}.overlay.png")
    trimmed.save(trimmed_path)
    overlay(trimmed, points, overlay_path)

    table = wall_table(trimmed, points) or prop_table(trimmed, points)
    print(f"asset  {args.asset}   render scale {args.scale:g}x")
    print(table or "no wall face markers — nothing to tabulate")
    print(f"\nwrote {trimmed_path}\nwrote {overlay_path}")


if __name__ == "__main__":
    main()
