"""customer_adult_idle_back -- chibi cast member; same figure turned 180 degrees (back view).
"""
from assets import figure_common as fc

CANVAS_UNITS = 1.2
LOOK_AT = (0.0, 0.0, 0.30)
OUTLINE_PX = 0.45


def build():
    return fc.build("CustomerAdult", fc.ADULT, pose="idle", back=True)
