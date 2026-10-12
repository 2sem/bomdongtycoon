"""customer_elder_walk -- chibi cast member; body plan and reasoning in figure_common.py.
Scale 0.933, white hair with a back bun.
"""
from assets import figure_common as fc

CANVAS_UNITS = 1.2 * 0.933
LOOK_AT = (0.0, 0.0, 0.30 * 0.933)
OUTLINE_PX = 0.45


def build():
    return fc.build("CustomerElder", fc.ELDER, scale=0.933, hair="elder", pose="walk")
