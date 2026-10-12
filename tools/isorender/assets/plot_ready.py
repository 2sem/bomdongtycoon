"""plot_ready -- farm plot stage; shared builder and reasoning in farm_common.py."""
from assets import farm_common as fc

CANVAS_UNITS = 1.4
LOOK_AT = (0.0, 0.0, 0.12)
OUTLINE_PX = 0.45


def build():
    fc.bed()
    # fat pale heads on a green outer-leaf collar: 2x3 big cubes
    outer, head = fc.mat("Outer", fc.LEAF), fc.mat("Head", fc.HEAD)
    for ri, r in enumerate((-0.19, 0.19)):
        for ci, c in enumerate((-0.2, 0.0, 0.2)):
            fc.box(f"O{ri}{ci}", (c, r), 0.20, 0.20, 0.08, 0.085, outer)
            fc.box(f"H{ri}{ci}", (c, r), 0.15, 0.15, 0.12, 0.165, head)
    # gold harvest flag on the back-right corner: 'ready' by shape, not colour
    fc.box("Pole", (0.30, -0.30), 0.03, 0.03, 0.40, 0.0, fc.mat("Pole", fc.TIMBER))
    fc.box("Flag", (0.30, -0.22), 0.04, 0.16, 0.12, 0.30, fc.mat("Flag", fc.GOLD))
    top = 0.42
    return fc.markers(top)
