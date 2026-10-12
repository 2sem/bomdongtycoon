"""Location road tile: ground_road_gangnam. Builder in `location_common.py`.

One cell slab standing in for `ground_tile_road`, panel `road_gangnam.png`.
"""

from assets import location_common

CANVAS_UNITS = 1.5
LOOK_AT = (0.0, 0.0, 0.0)
OUTLINE_PX = 0.45


def build():
    location_common.build_road(
        "ground_road_gangnam", panel="road_gangnam.png", top_rgba=(0.6, 0.62, 0.66, 1.0), side_rgba=(0.55, 0.58, 0.64, 1.0)
    )
    return {}
