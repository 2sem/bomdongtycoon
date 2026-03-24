# Splash Screen Image Generation Prompt

**Tool:** Sora
**Final result:** `Resources/Assets.xcassets/Splash.imageset/`

## Prompt

A cozy Korean street food stall at golden hour. Isometric casual mobile game art style,
warm and cheerful. Red-striped awning, Korean lanterns, wooden counter.

The sign above the stall reads "봄동 가게" in Korean.

On the counter: flat rosette-shaped bomdong cabbages stacked in a wooden crate,
a bowl of geotjeori (🥗), a steaming bibimbap (🥘).

**Staff at the stall (left to right):**
- A young part-time worker (알바생) cooking at the stove, holding a frying pan (🍳) — cabbage mascot head, apron
- A veteran part-timer (고참 알바) standing at the cash register, gold ₩ coin floating above — older, more confident posture, same cabbage mascot head
- A friendly middle-aged woman (이모님) preparing food at the counter — warm smile, apron

**Farm plot** (front-left of scene): a small garden with 2–3 bomdong plants growing in rows,
a farmer (농부) crouching down tending the crops — straw hat, gardening gloves.

A happy customer sits at a stool with coins (₩) floating up into the air.

Background: warm Korean alley at dusk with soft golden bokeh lights and
blurred buildings. The scene should feel lively, bustling, and atmospheric.

BOMDONG SHAPE — critical: bomdong (봄동) is NOT tall cylindrical napa cabbage (배추).
It is flat and wide like an open rosette or green rose viewed from above —
dark-green outer leaves spreading outward horizontally, pale yellow-green center,
short and low to the ground. All mascot heads must be this flat rosette shape.

## Notes

- Took ~5 iterations to get correct bomdong shape and "봄동 가게" sign text (v1 prompt)
- Key fix: explicitly state it is NOT 배추 (napa cabbage)
- Background must be specified — default was plain solid color
- Staff lineup updated to reflect: 알바생 (cook), 고참 알바 (cashier, ×1.4 income), 이모님, 농부 (farm)
- **v2 prompt (2026-03-24): Generated correctly in one shot** — all staff, farm, sign, and bomdong shape rendered as intended
