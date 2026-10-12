"""Shared builder for the location backdrops and road tiles.

Not an asset itself (nothing renders `location_common`). The nine location
pieces are thin modules over these two functions so that the three places
differ only in the numbers they pass: panel, height, coping colour. Same rig,
same camera, same ink weight, same one-cell-edge length.
"""

import isobuild
from isogrid import DIAMOND_VERTICES

#: A backdrop's depth. Thicker than the shop walls' 0.06 because it is a
#: building facade, not a plank; the end cap it exposes reads as wall mass.
BACKDROP_THICKNESS = 0.08
#: Road slab thickness, chosen so the trimmed tile's top face is 0.924 of its
#: height, the same fraction the shipped `ground_tile_road` has
#: (77.665 / (77.665 + 0.09 * 0.78744 * 89.095) = 0.924), so it sits on the
#: grid exactly where the current road tile does.
ROAD_THICKNESS = 0.09


def build_backdrop(label, edge, panel, height, face_rgba, coping_rgba):
    """One cell-edge-long facade standing on `edge` (a `(from, to)` pair of
    `DIAMOND_VERTICES` names), face toward the cell centre."""
    face = isobuild.flat_material(f"{label}Face", texture=panel, rgba=face_rgba)
    # End caps take the face colour darkened: lit full-strength they read as
    # a bright pilaster at every module joint.
    side = isobuild.flat_material(
        f"{label}Side", rgba=tuple(c * 0.72 for c in face_rgba[:3]) + (1.0,)
    )
    coping = isobuild.flat_material(f"{label}Coping", rgba=coping_rgba)
    isobuild.wall(
        label,
        start=DIAMOND_VERTICES[edge[0]],
        end=DIAMOND_VERTICES[edge[1]],
        height=height,
        thickness=BACKDROP_THICKNESS,
        face_material=face,
        trim_material=side,
        top_material=coping,
        inward_toward=(0.0, 0.0),
        plank_count=1,
    )


def build_road(label, panel, top_rgba, side_rgba):
    """One cell's road slab: textured top, plain side skirt."""
    top = isobuild.flat_material(f"{label}Top", texture=panel, rgba=top_rgba)
    side = isobuild.flat_material(f"{label}Side", rgba=side_rgba)
    isobuild.box(
        label,
        center=(0.0, 0.0),
        width=1.0,
        depth=1.0,
        height=ROAD_THICKNESS,
        face_material=side,
        trim_material=side,
        top_material=top,
    )
