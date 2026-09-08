"""The render rig: one camera, one light setup, one pixel scale, for every asset.

Run through Blender, never directly:

    blender -b -P tools/isorender/rig.py -- --asset wall_shop_left --scale 3

Everything that decides how a sprite ends up looking in the game — the
isometric projection, the light direction, the pixels-per-unit — lives here
and only here. Asset modules under `assets/` contribute geometry and nothing
else. That is the whole point: a set rendered through this file is coherent by
construction, instead of by hand-correcting each image afterwards.

Alongside the PNG the rig writes a `<asset>.markers.json` giving the exact
pixel position of named world points (a wall's face corners, a tile's
vertices), computed from the camera matrix. Those are ground truth — nobody
has to measure a rendered image by eye again.
"""

import argparse
import json
import math
import os
import sys

import bpy
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import isogrid  # noqa: E402  (needs the sys.path line above)


# --- Camera basis -----------------------------------------------------------


def _view_direction():
    """Unit vector pointing from the camera toward what it looks at."""
    elevation, yaw = isogrid.ELEVATION, isogrid.YAW
    return Vector(
        (
            -math.sin(yaw) * math.cos(elevation),
            math.cos(yaw) * math.cos(elevation),
            -math.sin(elevation),
        )
    )


def _screen_right():
    """The world direction that appears as "right" in the rendered image."""
    return Vector((math.cos(isogrid.YAW), math.sin(isogrid.YAW), 0.0))


def _screen_up():
    """The world direction that appears as "up" in the rendered image."""
    elevation, yaw = isogrid.ELEVATION, isogrid.YAW
    return Vector(
        (
            -math.sin(yaw) * math.sin(elevation),
            math.cos(yaw) * math.sin(elevation),
            math.cos(elevation),
        )
    )


# --- Scene ------------------------------------------------------------------


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def configure_render(scene, canvas_units, scale, samples, engine):
    """Pin the output to an exact pixels-per-unit, so a rendered length in
    pixels is a world length times a known constant — no measuring."""
    pixels = int(round(canvas_units * isogrid.pixels_per_unit(scale)))
    render = scene.render
    render.engine = engine
    render.resolution_x = pixels
    render.resolution_y = pixels
    render.resolution_percentage = 100
    render.film_transparent = True
    render.image_settings.file_format = "PNG"
    render.image_settings.color_mode = "RGBA"
    render.image_settings.compression = 15
    if engine == "CYCLES":
        scene.cycles.samples = samples
        scene.cycles.use_denoising = True
    return pixels


def add_camera(scene, ortho_scale, look_at):
    camera_data = bpy.data.cameras.new("IsoCamera")
    camera_data.type = "ORTHO"
    #: `ortho_scale` is the view width in world units along the larger render
    #: axis, so `resolution_x / ortho_scale` is the pixels-per-unit the render
    #: actually gets. The caller derives it from the *rounded* resolution
    #: rather than from the requested canvas size — rounding 534.57 px up to
    #: 535 would otherwise shift the scale by 0.08% and put every measured
    #: pixel a third of a pixel out.
    camera_data.ortho_scale = ortho_scale

    camera = bpy.data.objects.new("IsoCamera", camera_data)
    bpy.context.collection.objects.link(camera)
    camera.rotation_euler = (math.pi / 2.0 - isogrid.ELEVATION, 0.0, isogrid.YAW)
    camera.location = Vector(look_at) - _view_direction() * 10.0

    scene.camera = camera
    return camera


def add_lights(look_at, key_strength=3.5, fill_strength=0.9, ambient=0.35):
    """A fixed key from the screen's upper right, a weak fill from the left,
    and a little ambient lift — the style bible's "top faces lightest, front
    faces mid, side faces darkest", made mechanical."""
    right, up, back = _screen_right(), _screen_up(), -_view_direction()
    target = Vector(look_at)

    def sun(name, offset, strength, angle_degrees=8.0):
        data = bpy.data.lights.new(name, type="SUN")
        data.energy = strength
        data.angle = math.radians(angle_degrees)
        obj = bpy.data.objects.new(name, data)
        bpy.context.collection.objects.link(obj)
        obj.location = target + offset
        obj.rotation_euler = (-offset).to_track_quat("-Z", "Y").to_euler()
        return obj

    key = sun("KeySun", right * 2.5 + up * 3.0 + back * 2.0, key_strength)
    fill = sun("FillSun", right * -3.0 + up * 1.2 + back * 1.5, fill_strength, 25.0)

    world = bpy.data.worlds.new("IsoWorld")
    world.use_nodes = True
    background = world.node_tree.nodes["Background"]
    background.inputs["Color"].default_value = (0.85, 0.86, 0.9, 1.0)
    background.inputs["Strength"].default_value = ambient
    bpy.context.scene.world = world
    return key, fill


def add_outline(scene, view_layer, thickness_px):
    """The style's black ink outline, drawn by Freestyle rather than painted
    into every texture — so it stays one pixel weight across the whole set."""
    if thickness_px <= 0:
        scene.render.use_freestyle = False
        return None

    scene.render.use_freestyle = True
    scene.render.line_thickness_mode = "ABSOLUTE"
    scene.render.line_thickness = thickness_px

    settings = view_layer.freestyle_settings
    lineset = settings.linesets.new("outline")
    lineset.select_silhouette = True
    lineset.select_border = True
    lineset.select_crease = True
    linestyle = lineset.linestyle
    linestyle.color = (0.08, 0.06, 0.05)
    linestyle.thickness = thickness_px
    return lineset


# --- Markers ----------------------------------------------------------------


def collect_markers(extra=None):
    """Named grid-space points worth knowing the pixel position of."""
    markers = {
        f"tile_{name}": (col, row, 0.0)
        for name, (col, row) in isogrid.DIAMOND_VERTICES.items()
    }
    for obj in bpy.data.objects:
        for name, point in (obj.get("markers") or {}).items():
            markers[name] = tuple(point)
    markers.update(extra or {})
    return markers


def project_markers(scene, camera, markers):
    """Grid points -> pixel coordinates, top-left origin, y down — the same
    convention the measurement table hands to `ios-developer`."""
    width = scene.render.resolution_x
    height = scene.render.resolution_y
    projected = {}
    for name, (col, row, z) in markers.items():
        world = Vector(isogrid.world_point(col, row, z))
        ndc = world_to_camera_view(scene, camera, world)
        projected[name] = {
            "grid": [col, row, z],
            "x": round(ndc.x * width, 3),
            "y": round((1.0 - ndc.y) * height, 3),
        }
    return projected


# --- Entry point ------------------------------------------------------------


def parse_args(argv):
    parser = argparse.ArgumentParser(prog="rig.py")
    parser.add_argument("--asset", required=True, help="module name under assets/")
    parser.add_argument("--scale", type=float, default=3.0, help="supersampling factor")
    parser.add_argument("--out", default=os.path.join(HERE, "out"))
    parser.add_argument("--samples", type=int, default=128)
    parser.add_argument("--engine", default="CYCLES")
    parser.add_argument("--outline-px", type=float, default=None,
                        help="ink outline weight; defaults to 1px at 1x, scaled")
    return parser.parse_args(argv)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    args = parse_args(argv)

    reset_scene()
    asset = __import__(f"assets.{args.asset}", fromlist=["build"])

    canvas_units = getattr(asset, "CANVAS_UNITS", 2.0)
    look_at_grid = getattr(asset, "LOOK_AT", (0.0, 0.0, 0.0))
    look_at = isogrid.world_point(*look_at_grid)

    scene = bpy.context.scene
    pixels = configure_render(scene, canvas_units, args.scale, args.samples, args.engine)
    camera = add_camera(scene, pixels / isogrid.pixels_per_unit(args.scale), look_at)

    extra_markers = asset.build() or {}

    if getattr(asset, "UNLIT", False):
        scene.render.use_freestyle = False
    else:
        add_lights(look_at)
        outline = args.outline_px
        if outline is None:
            outline = getattr(asset, "OUTLINE_PX", 1.0) * args.scale
        add_outline(scene, bpy.context.view_layer, outline)

    os.makedirs(args.out, exist_ok=True)
    png_path = os.path.join(args.out, f"{args.asset}@{int(args.scale)}x.png")
    scene.render.filepath = png_path
    bpy.ops.render.render(write_still=True)

    markers = project_markers(scene, camera, collect_markers(extra_markers))
    report = {
        "asset": args.asset,
        "scale": args.scale,
        "canvas_units": canvas_units,
        "canvas_pixels": pixels,
        "pixels_per_unit": isogrid.pixels_per_unit(args.scale),
        "tile_width_px": isogrid.TILE_WIDTH * args.scale,
        "tile_height_px": isogrid.TILE_HEIGHT * args.scale,
        "elevation_degrees": math.degrees(isogrid.ELEVATION),
        "markers": markers,
    }
    json_path = os.path.join(args.out, f"{args.asset}.markers.json")
    with open(json_path, "w") as handle:
        json.dump(report, handle, indent=2)

    print(f"[isorender] wrote {png_path}")
    print(f"[isorender] wrote {json_path}")


if __name__ == "__main__":
    main()
