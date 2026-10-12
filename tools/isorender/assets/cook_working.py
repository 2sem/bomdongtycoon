"""cook_working -- staff figure; shared body plan and reasoning in staff_common.py."""
from assets import staff_common as sc

CANVAS_UNITS = 1.2
LOOK_AT = (0.0, 0.0, 0.34)
OUTLINE_PX = 0.45


def build():
    tool = dict(rgba=(0.62, 0.64, 0.68, 1.0), center=(0.0, 0.26), w=0.04, d=0.14, h=0.03, z0=0.36,
        extra=[dict(rgba=(0.40, 0.40, 0.43, 1.0), center=(0.0, 0.34), w=0.08, d=0.08, h=0.03, z0=0.36)])
    return sc.build_staff("Cook", working=True, tool=tool, **sc.COOK)
