#!/usr/bin/env python3
"""Compose App Store screenshots: a caption over a framed raw capture.

    tools/screenshots/capture.sh          # raw captures -> tools/screenshots/raw/<lang>/
    python3 tools/screenshots/compose.py  # -> fastlane/screenshots/<locale>/NN_name.png

Output is 1320x2868 (iPhone 6.9"), the one size App Store Connect scales down for every
smaller iPhone.
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
RAW = Path(__file__).resolve().parent / "raw"
OUT = ROOT / "fastlane" / "screenshots"
FONTS = ROOT / "Resources" / "Fonts"
sys.path.insert(0, str(ROOT / "tools" / "dotart"))
from palette import PALETTE  # noqa: E402

W, H = 1320, 2868
# One "dot" of the frame art. Every offset below is a multiple of it, so the caption, the
# bezel and the confetti sit on the same grid the game's own pixels do at this size.
DOT = 12


def rgb(name):
    value = PALETTE[name]
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))


# (raw capture, background top, background bottom, accent, ko headline, ko sub, en headline, en sub)
SHOTS = [
    ("late_noon", "sky", "blue", "gold_light",
     "봄동 포장마차\n사장님이 되어보세요", "심고 · 요리하고 · 팔고",
     "Run your own\nKorean food stall", "Grow it. Cook it. Sell it."),
    ("late_fever", "orange", "red_dark", "gold_light",
     "피버 타임!\n손님이 몰려온다", "게이지를 채우고 수익 폭발",
     "FEVER TIME!\nThe rush is on", "Fill the gauge, cash in big"),
    ("late_staff", "leaf", "leaf_deep", "gold_light",
     "직원을 고용해\n가게를 맡기세요", "알바생부터 봄동 요리사까지",
     "Hire a crew,\nlet them run it", "From part-timers to master chefs"),
    ("late_upgrades", "gold", "orange_dark", "paper",
     "메뉴도 가게도\n쑥쑥 업그레이드", "겉절이 · 봄동김치 · 봄동비빔밥",
     "Upgrade dishes\nand your shop", "Geotjeori, kimchi, bibimbap"),
    ("mid_petals", "pink", "red_dark", "paper",
     "골목에서 시장,\n강남까지 진출!", "가게가 커질수록 풍경도 달라져요",
     "From a back alley\nto Gangnam", "New streets as your stall grows"),
    ("late_offline", "mauve", "ink", "gold_light",
     "자리를 비워도\n코인은 쌓여요", "돌아오면 한 번에 수령",
     "Earn coins\nwhile you're away", "Come back and collect it all"),
    ("late_snow", "navy", "ink", "sky",
     "낮과 밤, 비와 눈\n살아있는 도트 세상", "날씨마다 달라지는 장사",
     "Day, night,\nrain and snow", "A living pixel world"),
]

LOCALES = {"ko": ("ko", 4, 5), "en": ("en-US", 6, 7)}


def background(top, bottom):
    """Vertical gradient quantised to DOT-high bands, dithered where two bands meet."""
    image = Image.new("RGB", (W, H))
    draw = ImageDraw.Draw(image)
    a, b = rgb(top), rgb(bottom)
    bands = 14
    band_height = H / bands
    for i in range(bands):
        t = i / (bands - 1)
        colour = tuple(round(a[c] + (b[c] - a[c]) * t) for c in range(3))
        y0 = round(i * band_height)
        draw.rectangle([0, y0, W, round((i + 1) * band_height)], fill=colour)
        if i:
            # Checker row of the new colour reaching one DOT up into the previous band.
            for x in range(0, W, DOT * 2):
                draw.rectangle([x, y0 - DOT, x + DOT - 1, y0 - 1], fill=colour)
    return image


def confetti(draw, accent, seed):
    """A sparse scatter of plus-shaped sparkles in the caption area; deterministic per shot."""
    state = seed * 7919 + 17
    colour = rgb(accent)
    for _ in range(16):
        state = (state * 1103515245 + 12345) & 0x7FFFFFFF
        x = (state % (W // DOT)) * DOT
        state = (state * 1103515245 + 12345) & 0x7FFFFFFF
        y = (state % (560 // DOT)) * DOT + DOT * 3
        # Keep the centre column clear for the text.
        if W * 0.14 < x < W * 0.86:
            continue
        d = DOT
        draw.rectangle([x, y - d, x + d - 1, y + 2 * d - 1], fill=colour)
        draw.rectangle([x - d, y, x + 2 * d - 1, y + d - 1], fill=colour)


def text_block(draw, text, font, y, fill, shadow, line_gap):
    """Centred lines with a hard one-DOT drop shadow. Returns the y below the block."""
    for line in text.split("\n"):
        left, top, right, bottom = draw.textbbox((0, 0), line, font=font)
        x = (W - (right - left)) // 2 - left
        offset = DOT * 2 // 3
        draw.text((x + offset, y + offset), line, font=font, fill=shadow)
        draw.text((x, y), line, font=font, fill=fill)
        y += font.size + line_gap
    return y


def framed(raw):
    """The capture scaled down inside a chunky ink bezel with a cream keyline."""
    scale = 0.8
    shot = raw.convert("RGB").resize((round(raw.width * scale), round(raw.height * scale)), Image.LANCZOS)
    radius, bezel, keyline = 96, DOT * 2, DOT // 2
    pad = bezel + keyline
    size = (shot.width + pad * 2, shot.height + pad * 2)
    frame = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(frame)
    draw.rounded_rectangle([0, 0, size[0] - 1, size[1] - 1], radius + pad, fill=rgb("cream"))
    draw.rounded_rectangle([keyline, keyline, size[0] - 1 - keyline, size[1] - 1 - keyline],
                           radius + bezel, fill=rgb("ink"))
    mask = Image.new("L", shot.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, shot.width - 1, shot.height - 1], radius, fill=255)
    frame.paste(shot, (pad, pad), mask)
    return frame


def compose(index, shot, lang):
    name, top, bottom, accent = shot[:4]
    locale, head_i, sub_i = LOCALES[lang]
    headline, sub = shot[head_i], shot[sub_i]
    raw_path = RAW / lang / f"{name}.png"
    if not raw_path.exists():
        print(f"skip {lang}/{name}: no raw capture")
        return

    image = background(top, bottom)
    draw = ImageDraw.Draw(image)
    confetti(draw, accent, index)

    # Galmuri11 is drawn on a 12 px em: sizes that are multiples of 12 stay pixel-crisp.
    head_font = ImageFont.truetype(str(FONTS / "Galmuri11-Bold.ttf"), 120)
    sub_font = ImageFont.truetype(str(FONTS / "Galmuri11.ttf"), 60)
    y = text_block(draw, headline, head_font, 132, rgb("paper"), rgb("ink"), 30)
    text_block(draw, sub, sub_font, y + 18, rgb(accent), rgb("ink"), 0)

    frame = framed(Image.open(raw_path))
    # The frame runs off the bottom edge: the tab bar is the least interesting strip.
    frame_y = 610
    shadow = Image.new("RGBA", frame.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle([0, 0, frame.width - 1, frame.height - 1], 96 + 30,
                                             fill=rgb("ink") + (90,))
    x = (W - frame.width) // 2
    image.paste(shadow, (x + DOT, frame_y + DOT * 2), shadow)
    image.paste(frame, (x, frame_y), frame)

    out = OUT / locale / f"{index + 1:02d}_{name}.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    image.save(out, optimize=True)
    print(out.relative_to(ROOT))


def main():
    for lang in LOCALES:
        for index, shot in enumerate(SHOTS):
            compose(index, shot, lang)


if __name__ == "__main__":
    main()
