"""Regenerates the PNG app icons from one 1024 x 1024 master image.

Usage, from frontend/ (needs Pillow: pip install pillow):

    python tool/generate_app_icons.py [master.png]

The master must be an opaque square PNG (iOS rejects icons with
transparency). By default it is the committed iOS marketing icon, so running
the script with no argument rebuilds the smaller sizes from it. The script
writes every size listed in the iOS AppIcon set and the legacy Android
launcher icons. Android 8 and later use the vector adaptive icon in
android/app/src/main/res/drawable instead; edit those files by hand. The
vector sources for every brand asset are in docs/brand.
"""

import json
import sys
from pathlib import Path

from PIL import Image

FRONTEND = Path(__file__).resolve().parent.parent
IOS_ICON_SET = FRONTEND / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
IOS_MASTER = IOS_ICON_SET / "Icon-App-1024x1024@1x.png"
ANDROID_RES = FRONTEND / "android/app/src/main/res"
# Legacy launcher icons are 48 dp.
ANDROID_LEGACY_PX = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
MASTER_PX = 1024


def main() -> None:
    source = Path(sys.argv[1]) if len(sys.argv) > 1 else IOS_MASTER
    with Image.open(source) as image:
        master = image.convert("RGBA")
    if master.size != (MASTER_PX, MASTER_PX):
        sys.exit(f"{source} must be {MASTER_PX} x {MASTER_PX} px, not {master.size}")
    if master.getextrema()[3][0] < 255:
        sys.exit(f"{source} has transparent pixels; iOS needs an opaque icon")
    master = master.convert("RGB")

    contents = json.loads((IOS_ICON_SET / "Contents.json").read_text(encoding="utf-8"))
    for entry in contents["images"]:
        points = float(entry["size"].split("x")[0])
        scale = int(entry["scale"].rstrip("x"))
        save(master, round(points * scale), IOS_ICON_SET / entry["filename"])

    for density, px in ANDROID_LEGACY_PX.items():
        save(master, px, ANDROID_RES / f"mipmap-{density}" / "ic_launcher.png")


def save(master: Image.Image, px: int, path: Path) -> None:
    icon = master if px == MASTER_PX else master.resize((px, px), Image.Resampling.LANCZOS)
    # Pillow writes no metadata chunks unless asked to, so the files stay small.
    icon.save(path, optimize=True)
    print(f"{path.relative_to(FRONTEND)}  {px} px")


if __name__ == "__main__":
    main()
