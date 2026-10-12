"""farmer_working -- staff figure; shared body plan and reasoning in staff_common.py."""
from assets import staff_common as sc

CANVAS_UNITS = 1.2
LOOK_AT = (0.0, 0.0, 0.34)
OUTLINE_PX = 0.45


def build():
    tool = dict(rgba=(0.45, 0.30, 0.18, 1.0), center=(0.0, 0.26), w=0.025, d=0.025, h=0.52, z0=0.0,
        extra=[dict(rgba=(0.62, 0.64, 0.68, 1.0), center=(0.0, 0.26), w=0.10, d=0.04, h=0.04, z0=0.50)])
    return sc.build_staff("Farmer", working=True, tool=tool, **sc.FARMER)
