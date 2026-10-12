"""The game's isometric grid, as plain numbers.

This module is deliberately free of `bpy` so that both the Blender-side rig
and the PIL-side post-processing can import it and agree on the geometry.

Everything here is *derived* from what the running game already does — see
`Sources/App/Nodes/GroundLayerNode.swift` and
`Sources/App/Nodes/Tiles/GrassGroundTileNode.swift`. Nothing is invented. If
the game's grid changes, change it here and re-render the set; do not tune a
single asset by hand.
"""

from math import asin, cos, degrees, radians, sin, sqrt

# --- What the game says -----------------------------------------------------

#: `GrassGroundTileNode.footprintWidth` — the grass art defines the grid unit.
FOOTPRINT_WIDTH = 128.0
#: Native pixel size of `ground_tile_grass.png`, used for its aspect.
GRASS_NATIVE_SIZE = (1024.0, 678.0)
#: `GrassGroundTileNode.topFaceHeightFraction` — how much of the sprite is the
#: flat diamond face, the rest being the dirt skirt hanging south.
TOP_FACE_HEIGHT_FRACTION = 0.940
#: `GroundLayer.spacingInset` — flat point-based tightening on both axes.
SPACING_INSET = -2.0

#: Screen-point spacing between adjacent tile centers, i.e. the on-screen size
#: of one cell's diamond. `GroundLayer.grid`.
TILE_WIDTH = FOOTPRINT_WIDTH + SPACING_INSET
TILE_HEIGHT = (
    FOOTPRINT_WIDTH * (GRASS_NATIVE_SIZE[1] / GRASS_NATIVE_SIZE[0]) * TOP_FACE_HEIGHT_FRACTION
    + SPACING_INSET
)

# --- What that implies for a camera -----------------------------------------

#: A unit square lying flat, yawed 45deg under an orthographic camera at
#: elevation `theta`, projects to a diamond of width `s*sqrt(2)` and height
#: `s*sqrt(2)*sin(theta)`. So the grid's own aspect *is* `sin(theta)`.
DIAMOND_ASPECT = TILE_HEIGHT / TILE_WIDTH
ELEVATION = asin(DIAMOND_ASPECT)  # radians, ~38.052deg

#: Camera yaw. At this yaw the world axes land on screen the way the game's
#: `IsoGrid` expects: `col` runs to the lower-right, `row` to the lower-left.
#: See `world_point` — authors should never touch the raw axes.
YAW = radians(135.0)

#: A world-vertical edge stays *screen-vertical* under an orthographic camera
#: with no roll; it is only foreshortened by this factor. This single fact is
#: what removes the per-asset homography correction from the old pipeline.
VERTICAL_FORESHORTENING = cos(ELEVATION)

#: One world unit is one cell edge, in screen points.
UNIT_POINTS = TILE_WIDTH / sqrt(2.0)


def pixels_per_unit(scale: float) -> float:
    """Render pixels per world unit at the given supersampling `scale`."""
    return UNIT_POINTS * scale


def view_direction():
    """Unit vector pointing from the camera toward what it looks at.

    Pure function of `YAW`/`ELEVATION`, no `bpy` — so `isobuild.py`'s shape
    vocabulary can tell which side of a face the fixed camera actually sees
    without touching scene state, the same reason this module carries no
    `bpy` dependency at all.
    """
    return (
        -sin(YAW) * cos(ELEVATION),
        cos(YAW) * cos(ELEVATION),
        -sin(ELEVATION),
    )


def world_point(col: float, row: float, height: float = 0.0):
    """Grid coordinates -> Blender world coordinates.

    `col`/`row` are in cell units and match the game's `IsoGrid` exactly:
    cell `(0, 0)` is centered on the world origin and its diamond corners are
    at the half-steps, e.g. the shop's West vertex is `(-0.5, +0.5)`.

    `height` is straight up, in the same unit.

    The axis swap (`col` -> world Y, `row` -> world X) is what makes `YAW`
    put `col` on the screen's lower-right. It is an implementation detail of
    this pairing; asset modules should call this and forget about it.
    """
    return (row, col, height)


#: The four corners of a cell's diamond, in grid coordinates, named the way
#: `.claude/agents/2.5d-game-designer.md` names them.
DIAMOND_VERTICES = {
    "west": (-0.5, +0.5),
    "south": (+0.5, +0.5),
    "east": (+0.5, -0.5),
    "north": (-0.5, -0.5),
}


def describe() -> str:
    """A one-screen summary, printed by `--describe` and by the calibration."""
    return "\n".join(
        [
            f"tile size        {TILE_WIDTH:.3f} x {TILE_HEIGHT:.3f} pt",
            f"diamond aspect   {DIAMOND_ASPECT:.5f}",
            f"camera elevation {degrees(ELEVATION):.3f} deg",
            f"camera yaw       {degrees(YAW):.3f} deg",
            f"vertical scale   {VERTICAL_FORESHORTENING:.5f} (cos elevation)",
            f"world unit       {UNIT_POINTS:.3f} pt (one cell edge)",
            f"px/unit @3x      {pixels_per_unit(3.0):.3f}",
            f"sin/cos check    {sin(ELEVATION):.5f} == {DIAMOND_ASPECT:.5f}",
        ]
    )


if __name__ == "__main__":
    print(describe())
