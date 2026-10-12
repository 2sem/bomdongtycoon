"""plot_empty -- farm plot stage; shared builder and reasoning in farm_common.py."""
from assets import farm_common as fc

CANVAS_UNITS = 1.4
LOOK_AT = (0.0, 0.0, 0.12)
OUTLINE_PX = 0.45


def build():
    fc.bed()
    top = 0.09
    return fc.markers(top)
