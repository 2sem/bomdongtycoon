"""plot_sprout -- farm plot stage; shared builder and reasoning in farm_common.py."""
from assets import farm_common as fc

CANVAS_UNITS = 1.4
LOOK_AT = (0.0, 0.0, 0.12)
OUTLINE_PX = 0.45


def build():
    fc.bed()
    top = fc.plants(2, 0.05, 0.07, 0.025)
    return fc.markers(top)
