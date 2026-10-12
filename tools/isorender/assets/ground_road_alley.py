"""Location road tile: ground_road_alley. Builder in `location_common.py`.

One cell slab standing in for `ground_tile_road`, panel `road_alley.png`.
"""

from assets import location_common

CANVAS_UNITS = 1.5
LOOK_AT = (0.0, 0.0, 0.0)
OUTLINE_PX = 0.45


def build():
    location_common.build_road(
        "ground_road_alley", panel="road_alley.png", top_rgba=(0.58, 0.57, 0.55, 1.0), side_rgba=(0.36, 0.35, 0.34, 1.0)
    )
    return {}
