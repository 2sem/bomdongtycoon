"""Location road tile: ground_road_market. Builder in `location_common.py`.

One cell slab standing in for `ground_tile_road`, panel `road_market.png`.
"""

from assets import location_common

CANVAS_UNITS = 1.5
LOOK_AT = (0.0, 0.0, 0.0)
OUTLINE_PX = 0.45


def build():
    location_common.build_road(
        "ground_road_market", panel="road_market.png", top_rgba=(0.75, 0.62, 0.45, 1.0), side_rgba=(0.34, 0.26, 0.18, 1.0)
    )
    return {}
