"""plot_add -- farm plot stage; shared builder and reasoning in farm_common.py."""
from assets import farm_common as fc

CANVAS_UNITS = 1.4
LOOK_AT = (0.0, 0.0, 0.12)
OUTLINE_PX = 0.45


def build():
    pale = fc.mat("AddFrame", (0.66, 0.54, 0.34, 1.0))
    sand = fc.mat("AddGround", (0.50, 0.40, 0.24, 1.0))
    fc.frame(pale, h=0.04, t=0.06)
    fc.box("Ground", (0.0, 0.0), fc.BED - 0.12, fc.BED - 0.12, 0.02, 0.0, sand)
    plus = fc.mat("Plus", fc.GOLD)
    fc.box("PlusH", (0.0, 0.0), 0.36, 0.10, 0.06, 0.02, plus)
    fc.box("PlusV", (0.0, 0.0), 0.10, 0.36, 0.07, 0.02, plus)
    top = 0.09
    return fc.markers(top)
