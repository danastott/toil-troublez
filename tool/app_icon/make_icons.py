#!/usr/bin/env python3
"""Generate the Toil & Troublez app icon PNGs from icon.svg.

Renders the SVG natively at each size (no downscale blur) and writes the
files in place: the iOS AppIcon set, the macOS AppIcon set, and the five
Android mipmap densities. Re-run any time icon.svg changes.

Usage:
  python3 make_icons.py            # regenerate everything

Requires cairosvg. On macOS: brew install cairo, then
  /opt/homebrew/bin/python3.12 -m pip install --user --break-system-packages cairosvg
and run with DYLD_LIBRARY_PATH=/opt/homebrew/lib.
"""

import pathlib

import cairosvg

HERE = pathlib.Path(__file__).parent
ROOT = HERE.parent.parent
SVG = HERE / "icon.svg"

IOS_SET = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
MAC_SET = ROOT / "macos/Runner/Assets.xcassets/AppIcon.appiconset"
ANDROID_RES = ROOT / "android/app/src/main/res"

# filename -> pixel size (matches each Contents.json / res layout)
IOS_SIZES = {
    "Icon-App-20x20@1x.png": 20,
    "Icon-App-20x20@2x.png": 40,
    "Icon-App-20x20@3x.png": 60,
    "Icon-App-29x29@1x.png": 29,
    "Icon-App-29x29@2x.png": 58,
    "Icon-App-29x29@3x.png": 87,
    "Icon-App-40x40@1x.png": 40,
    "Icon-App-40x40@2x.png": 80,
    "Icon-App-40x40@3x.png": 120,
    "Icon-App-60x60@2x.png": 120,
    "Icon-App-60x60@3x.png": 180,
    "Icon-App-76x76@1x.png": 76,
    "Icon-App-76x76@2x.png": 152,
    "Icon-App-83.5x83.5@2x.png": 167,
    "Icon-App-1024x1024@1x.png": 1024,
}
MAC_SIZES = {f"app_icon_{s}.png": s for s in (16, 32, 64, 128, 256, 512, 1024)}
ANDROID_SIZES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}


def render(px: int, out: pathlib.Path) -> None:
    cairosvg.svg2png(url=str(SVG), write_to=str(out), output_width=px, output_height=px)


def main() -> None:
    written = []

    for name, px in IOS_SIZES.items():
        p = IOS_SET / name
        render(px, p)
        written.append(p)

    for name, px in MAC_SIZES.items():
        p = MAC_SET / name
        render(px, p)
        written.append(p)

    for density, px in ANDROID_SIZES.items():
        p = ANDROID_RES / density / "ic_launcher.png"
        render(px, p)
        written.append(p)

    print(f"wrote {len(written)} icons:")
    for p in written:
        print(f"  {p.relative_to(ROOT)}  ({p.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
