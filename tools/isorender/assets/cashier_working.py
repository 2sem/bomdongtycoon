"""cashier_working -- chibi cast member; body plan and reasoning in figure_common.py.
"""
from assets import figure_common as fc

CANVAS_UNITS = 1.2
LOOK_AT = (0.0, 0.0, 0.34)
OUTLINE_PX = 0.45


def build():
    return fc.build("Cashier", fc.CASHIER, hat="cap", apron=True, pose="work", tool="register")
