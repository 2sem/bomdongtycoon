"""cashier_working -- staff figure; shared body plan and reasoning in staff_common.py."""
from assets import staff_common as sc

CANVAS_UNITS = 1.2
LOOK_AT = (0.0, 0.0, 0.34)
OUTLINE_PX = 0.45


def build():
    tool = dict(rgba=(0.55, 0.58, 0.62, 1.0), center=(0.0, 0.26), w=0.10, d=0.08, h=0.05, z0=0.36)
    return sc.build_staff("Cashier", working=True, tool=tool, **sc.CASHIER)
