"""Puts app screenshots into a phone frame for the README.

Usage, from frontend/ (needs Pillow: pip install pillow):

    python tool/frame_screenshots.py ios ../docs/screenshots/ios 01-garage.png ...
    python tool/frame_screenshots.py android ../docs/screenshots/android 01-garage.png ...

The first argument picks the frame: an iPhone (titanium rim, Dynamic Island,
buttons on both sides) or an Android phone (punch-hole camera, buttons on the
right). Each screenshot is written as a transparent PNG with the same file
name into the output folder. Use full-screen portrait screenshots, including
the status bar, taken with sample data only (docs/screenshots/README.md).
"""

import sys
from pathlib import Path

from PIL import Image, ImageDraw

# Width of the screen inside the frame, in output pixels: twice the width the
# README shows, so phones stay sharp on high-density displays.
SCREEN_WIDTH = 460
# Drawn this many times larger, then scaled down, for smooth curves.
SUPERSAMPLE = 3

# Proportions relative to the screen width.
FRAMES = {
    "ios": {
        "screen_radius": 0.125,
        "bezel": 0.032,
        "rim": 0.014,
        "rim_light": (222, 222, 226),
        "rim_dark": (150, 150, 156),
        # (side, top, length) as fractions of the body height.
        "buttons": [
            ("left", 0.135, 0.032),  # action button
            ("left", 0.205, 0.058),  # volume up
            ("left", 0.280, 0.058),  # volume down
            ("right", 0.230, 0.095),  # side button
        ],
    },
    "android": {
        "screen_radius": 0.085,
        "bezel": 0.036,
        "rim": 0.013,
        "rim_light": (214, 216, 220),
        "rim_dark": (140, 142, 148),
        "buttons": [
            ("right", 0.170, 0.055),  # power
            ("right", 0.255, 0.110),  # volume rocker
        ],
    },
}
BUTTON_DEPTH = 0.009
BEZEL_COLOR = (8, 8, 10)
CAMERA_COLOR = (0, 0, 0)
LENS_COLOR = (28, 30, 40)


def rounded_mask(size, radius):
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, size[0] - 1, size[1] - 1), radius=radius, fill=255
    )
    return mask


def metal(size, radius, light, dark):
    """A rounded slab shaded like a metal rim: darker at the left and right edges."""
    width, height = size
    stops = [(0.0, dark), (0.08, light), (0.92, light), (1.0, dark)]
    row = Image.new("RGB", (width, 1))
    for x in range(width):
        p = x / (width - 1)
        for (pa, ca), (pb, cb) in zip(stops, stops[1:]):
            if pa <= p <= pb:
                k = (p - pa) / (pb - pa)
                row.putpixel((x, 0), tuple(round(a + (b - a) * k) for a, b in zip(ca, cb)))
                break
    slab = Image.new("RGBA", size, (0, 0, 0, 0))
    slab.paste(row.resize(size), (0, 0), rounded_mask(size, radius))
    return slab


def frame(shot, platform):
    spec = FRAMES[platform]
    s = SCREEN_WIDTH * SUPERSAMPLE
    screen = shot.convert("RGB").resize(
        (s, round(s * shot.height / shot.width)), Image.LANCZOS
    )
    screen_radius = spec["screen_radius"] * s
    bezel = spec["bezel"] * s
    rim = spec["rim"] * s
    light, dark = spec["rim_light"], spec["rim_dark"]
    button = BUTTON_DEPTH * s

    body_w = s + 2 * (bezel + rim)
    body_h = screen.height + 2 * (bezel + rim)
    pad = button + 2
    canvas = Image.new(
        "RGBA", (round(body_w + 2 * pad), round(body_h + 2 * pad)), (0, 0, 0, 0)
    )
    draw = ImageDraw.Draw(canvas)

    # Buttons first, so the body covers their inner ends.
    for side, top, length in spec["buttons"]:
        x = pad - button if side == "left" else pad + body_w - 2
        draw.rounded_rectangle(
            (x, pad + top * body_h, x + button + 2, pad + (top + length) * body_h),
            radius=button * 0.6,
            fill=dark,
        )

    outer_radius = screen_radius + bezel + rim
    canvas.alpha_composite(
        metal((round(body_w), round(body_h)), outer_radius, light, dark),
        (round(pad), round(pad)),
    )
    draw.rounded_rectangle(
        (pad, pad, pad + body_w - 1, pad + body_h - 1),
        radius=outer_radius,
        outline=dark,
        width=max(2, SUPERSAMPLE),
    )
    draw.rounded_rectangle(
        (pad + rim, pad + rim, pad + body_w - rim - 1, pad + body_h - rim - 1),
        radius=screen_radius + bezel,
        fill=BEZEL_COLOR,
    )
    sx, sy = round(pad + rim + bezel), round(pad + rim + bezel)
    canvas.paste(screen, (sx, sy), rounded_mask(screen.size, screen_radius))

    if platform == "ios":
        # Dynamic Island, centered in the status bar's empty middle.
        width, height, top = 0.285 * s, 0.084 * s, 0.026 * s
        draw.rounded_rectangle(
            (sx + (s - width) / 2, sy + top, sx + (s + width) / 2, sy + top + height),
            radius=height / 2,
            fill=CAMERA_COLOR,
        )
    else:
        diameter, center_y = 0.040 * s, 0.065 * s
        cx, cy = sx + s / 2, sy + center_y
        draw.ellipse(
            (cx - diameter / 2, cy - diameter / 2, cx + diameter / 2, cy + diameter / 2),
            fill=CAMERA_COLOR,
        )
        lens = diameter * 0.18
        draw.ellipse((cx - lens, cy - lens, cx + lens, cy + lens), fill=LENS_COLOR)

    return canvas.resize(
        (canvas.width // SUPERSAMPLE, canvas.height // SUPERSAMPLE), Image.LANCZOS
    )


def main():
    if len(sys.argv) < 4 or sys.argv[1] not in FRAMES:
        sys.exit(__doc__)
    platform, out_dir, files = sys.argv[1], Path(sys.argv[2]), sys.argv[3:]
    out_dir.mkdir(parents=True, exist_ok=True)
    for file in files:
        path = Path(file)
        target = out_dir / f"{path.stem}.png"
        frame(Image.open(path), platform).save(target, optimize=True)
        print(f"wrote {target}")


if __name__ == "__main__":
    main()
