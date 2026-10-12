"""Location backdrop: backdrop_market_back_right. Builder in `location_common.py`.

One cell edge (North->East), HEIGHT 1.15 units, panel `backdrop_market_right.png`
(procedural, `textures/make_location_panels.py`). The shop's own back walls
are 0.709, so this stands 1.6x the shop roofline.
"""

from assets import location_common

CANVAS_UNITS = 2.0
LOOK_AT = (0.0, -0.5, 0.575)
OUTLINE_PX = 0.45

HEIGHT = 1.15


def build():
    location_common.build_backdrop(
        "backdrop_market_back_right",
        edge=('north', 'east'),
        panel="backdrop_market_right.png",
        height=HEIGHT,
        face_rgba=(0.7, 0.47, 0.26, 1.0),
        coping_rgba=(0.50, 0.12, 0.09, 1.0),
    )
    return {}
