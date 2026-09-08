"""Not art — the rig's own test.

Renders one flat cell as solid white. Its alpha-trimmed bounding box must come
out at exactly `tileWidth x tileHeight` times the render scale (378 x 233 px at
3x). If this is off, the camera elevation, yaw or pixel scale is wrong and no
render downstream can be trusted, so run it first and after any change to
`rig.py` or `isogrid.py`.
"""

import isobuild

CANVAS_UNITS = 2.0
LOOK_AT = (0.0, 0.0, 0.0)
UNLIT = True  # lighting would only add gradient noise to a measurement


def build():
    material = isobuild.emission_material("CalibrationWhite")
    isobuild.plane("CalibrationCell", material, size=1.0)
    return {}
