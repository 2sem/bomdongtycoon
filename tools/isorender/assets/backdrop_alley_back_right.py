"""Location backdrop: backdrop_alley_back_right. Builder in `location_common.py`.

One cell edge (North->East), HEIGHT 1.6 units, panel `backdrop_alley_right.png`
(procedural, `textures/make_location_panels.py`). The shop's own back walls
are 0.709, so this stands 2.3x the shop roofline.
"""

from assets import location_common

CANVAS_UNITS = 2.0
LOOK_AT = (0.0, -0.5, 0.8)
OUTLINE_PX = 0.45

HEIGHT = 1.6


def build():
    location_common.build_backdrop(
        "backdrop_alley_back_right",
        edge=('north', 'east'),
        panel="backdrop_alley_right.png",
        height=HEIGHT,
        face_rgba=(0.52, 0.48, 0.44, 1.0),
        coping_rgba=(0.52, 0.49, 0.45, 1.0),
    )
    return {}
