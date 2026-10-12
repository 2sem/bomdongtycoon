"""Location backdrop: backdrop_gangnam_back_right. Builder in `location_common.py`.

One cell edge (North->East), HEIGHT 2.4 units, panel `backdrop_gangnam_right.png`
(procedural, `textures/make_location_panels.py`). The shop's own back walls
are 0.709, so this stands 3.4x the shop roofline.
"""

from assets import location_common

CANVAS_UNITS = 3.0
LOOK_AT = (0.0, -0.5, 1.2)
OUTLINE_PX = 0.45

HEIGHT = 2.4


def build():
    location_common.build_backdrop(
        "backdrop_gangnam_back_right",
        edge=('north', 'east'),
        panel="backdrop_gangnam_right.png",
        height=HEIGHT,
        face_rgba=(0.3, 0.38, 0.52, 1.0),
        coping_rgba=(0.42, 0.46, 0.55, 1.0),
    )
    return {}
