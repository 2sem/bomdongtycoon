# isorender — flat art in, isometric sprite out

Sprites used to be produced by asking an image generator for an already-isometric
drawing and then repairing it: a hand-computed 4-point homography to force the
vertical edges vertical, a beige background key, an alpha trim, a mirror to derive
the paired wall, a relight to make it match the set. That repair was redone from
scratch for every asset and nothing but the finished PNG was ever committed.

This replaces the repair with a scripted orthographic render. The generator is only
asked for **flat, head-on texture panels** — the thing it is actually good at — and
the rig supplies the geometry: projection, shear, vertical edges, foreshortening,
light direction, ink outline, and pixel scale. Every asset rendered through it is
coherent with every other one by construction.

## Requirements

```sh
brew install --cask blender     # 5.2.1; the only prerequisite
```

Python-side post-processing uses PIL, which is already present.

## Use

```sh
tools/isorender/render.sh calibrate         # verify the rig itself, first
tools/isorender/render.sh wall_shop_left    # render + trim + measure
```

Output lands in `tools/isorender/out/` (git-ignored — renders are reproducible
from the specs):

| File | What it is |
|---|---|
| `<asset>@3x.png` | the raw render, transparent background |
| `<asset>.png` | alpha-trimmed, ready for an imageset |
| `<asset>.overlay.png` | the same with the measured corners drawn on |
| `<asset>.markers.json` | named world points projected to exact pixels |

## The geometry, and where it comes from

Nothing here is a chosen number. Everything is derived from what the running game
already does (`Sources/App/Nodes/GroundLayerNode.swift`,
`Sources/App/Nodes/Tiles/GrassGroundTileNode.swift`), and lives in `isogrid.py`:

| Quantity | Value | Why |
|---|---|---|
| `tileWidth` | 126 | `footprintWidth 128` + `spacingInset −2` |
| `tileHeight` | 77.665 | `128·(678/1024)·0.940 − 2` |
| diamond aspect | 0.61639 | `tileHeight / tileWidth` |
| camera elevation | 38.053° | a unit square yawed 45° under an ortho camera at elevation θ projects to a diamond of aspect `sin θ`, so `θ = asin(0.61639)` |
| camera yaw | 135° | puts `col` on the screen's lower-right and `row` on its lower-left, matching `IsoGrid` |
| vertical foreshortening | 0.78744 | `cos θ` |
| world unit | 89.095 pt | one cell edge; `tileWidth / √2` |
| px per unit @3× | 267.286 | |

Two consequences worth knowing:

* **Vertical edges stay vertical.** An orthographic camera with no roll cannot
  tilt a world-vertical. That single fact is what deletes the homography step.
* **`ortho_scale` is derived from the rounded pixel resolution**, not from the
  requested canvas width. Rounding 534.57 px up to 535 would otherwise shift the
  scale by 0.08% and put every measured pixel a third of a pixel out.

Run `python3 tools/isorender/isogrid.py` to print the table above.

## Adding an asset

Add a module under `assets/`. It contributes geometry and nothing else — the
camera, lights and scale are not its business:

```python
import isobuild
from isogrid import DIAMOND_VERTICES

CANVAS_UNITS = 2.0            # view width in world units (1 unit = one cell edge)
LOOK_AT = (0.0, 0.5, 0.35)    # grid coords the camera centers on
OUTLINE_PX = 1.0              # ink outline weight at 1x

def build():
    planks = isobuild.flat_material("Planks", texture="plank_wall.png")
    isobuild.wall(
        "ShopWallLeft",
        start=DIAMOND_VERTICES["west"],
        end=DIAMOND_VERTICES["south"],
        height=0.709,
        thickness=0.06,
        face_material=planks,
        inward_toward=(0.0, 0.0),
    )
    return {}
```

`isobuild.wall` records the face corners as markers, so the measurement table
comes out without anyone measuring anything.

A missing texture is not an error — the material falls back to a flat colour, so
geometry can be checked before the art exists.

## Texture panels

`textures/` holds the only generated input left in the pipeline. A panel must be:

* **flat and head-on** — no perspective, no shear, no visible corner;
* **evenly lit** — no vignette, no gradient, no baked shadow. The rig lights it,
  and baked lighting fights the rig's;
* **borderless** — no ink outline drawn in. Freestyle draws the outline, so a
  painted one would double up;
* **edge to edge** — no background, floor, sky, or props.

Panels are reusable: the same plank texture serves every wall in the set, which is
half the reason the set stays coherent.

## Measurement contract

`postprocess.py` prints the table
`.claude/agents/2.5d-game-designer.md` hands to `ios-developer`: trimmed size, the
four face corners, which corner sits on the tile vertex, the anchor fractions, the
depth vector and the face slope — plain pixels, top-left origin, y down.

The numbers come from `markers.json`, i.e. from the camera matrix. Antialiasing
spreads a rendered edge over about a pixel, so an alpha bounding box and the true
geometry disagree by ~1 px at 3×; the projected markers do not.

## Calibration

`render.sh calibrate` renders one flat cell as unlit white and checks it measures
exactly one tile. It must print `CALIBRATION PASS`. Run it first, and after any
change to `rig.py` or `isogrid.py` — if the rig's own cell is wrong, nothing
rendered through it can be right.
