"""cook_idle -- staff figure; shared body plan and reasoning in staff_common.py."""
from assets import staff_common as sc

CANVAS_UNITS = 1.2
LOOK_AT = (0.0, 0.0, 0.34)
OUTLINE_PX = 0.45


def build():
    tool = None
    return sc.build_staff("Cook", working=False, tool=tool, **sc.COOK)
