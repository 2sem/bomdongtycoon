"""customer_kid_walk -- chibi cast member; body plan and reasoning in figure_common.py.
Scale 0.70 with a 10% larger head and bigger face; hair buns.
"""
from assets import figure_common as fc

CANVAS_UNITS = 1.2 * 0.70
LOOK_AT = (0.0, 0.0, 0.30 * 0.70)
OUTLINE_PX = 0.45


def build():
    return fc.build("CustomerKid", fc.KID, scale=0.70, head_k=1.10, face_k=1.10, hair="buns", pose="walk")
