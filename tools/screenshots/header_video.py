#!/usr/bin/env python3
"""App Store header video: the header.py panorama, moving, as a seamless loop.

    python3 tools/screenshots/header_video.py   # -> fastlane/header/<locale>_3840x1646.mp4

App Store Connect takes a 3840x1646 header video of 5 to 30 s at 30 or 60 fps and loops it
without a pause, so the last frame has to run into the first: header.LOOP is the period every
motion in the scene divides. Needs ffmpeg with libx264.
"""
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import header  # noqa: E402
from header import LOOP, OUT, ROOT, SIGNS, sprites  # noqa: E402

(WIDTH, HEIGHT), SCALE = header.SIZES[0]
FPS = 30


def lettering(locale, x0, shop_top):
    """Signboard names on a transparent layer; they sit still over the moving art."""
    layer = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    header.signs(layer, SIGNS[locale], SCALE, x0, shop_top)
    return layer


def encode(frames, art_size, overlay, path):
    """Art-pixel frames in, H.264 out. ffmpeg does the nearest-neighbour upscale and the overlay."""
    w, h = art_size
    graph = (
        f"[0:v]scale={w * SCALE}:{h * SCALE}:flags=neighbor,crop={WIDTH}:{HEIGHT}:0:0[art];"
        # format=rgb keeps the composite in RGB, so the one conversion to YUV is the tagged BT.709 one.
        "[art][1:v]overlay=format=rgb,"
        "scale=out_color_matrix=bt709:out_range=tv,format=yuv420p[v]"
    )
    command = [
        "ffmpeg", "-loglevel", "error", "-y",
        "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{w}x{h}", "-r", str(FPS), "-i", "-",
        "-i", str(overlay),
        # A silent track: the header plays muted, but App Store Connect rejects previews without audio.
        "-f", "lavfi", "-i", "anullsrc=r=44100:cl=stereo",
        "-filter_complex", graph, "-map", "[v]", "-map", "2:a", "-shortest",
        "-c:v", "libx264", "-preset", "slow", "-crf", "14", "-profile:v", "high",
        "-color_primaries", "bt709", "-color_trc", "bt709", "-colorspace", "bt709",
        "-c:a", "aac", "-b:a", "64k", "-movflags", "+faststart", str(path),
    ]
    ffmpeg = subprocess.Popen(command, stdin=subprocess.PIPE)
    for frame in frames:
        ffmpeg.stdin.write(frame)
    ffmpeg.stdin.close()
    if ffmpeg.wait():
        sys.exit(f"ffmpeg failed on {path.name}")


def main():
    sprites.load_all()
    OUT.mkdir(parents=True, exist_ok=True)
    art_size = (-(-WIDTH // SCALE), -(-HEIGHT // SCALE))
    frames = []
    for f in range(LOOP):
        art, x0, shop_top = header.world(*art_size, f)
        frames.append(art.convert("RGB").tobytes())
    with tempfile.TemporaryDirectory() as scratch:
        for locale in SIGNS:
            overlay = Path(scratch) / f"{locale}.png"
            lettering(locale, x0, shop_top).save(overlay)
            path = OUT / f"{locale}_{WIDTH}x{HEIGHT}.mp4"
            encode(frames, art_size, overlay, path)
            print(path.relative_to(ROOT))


if __name__ == "__main__":
    main()
