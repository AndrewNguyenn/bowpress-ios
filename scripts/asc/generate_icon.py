#!/usr/bin/env python3
"""Generate 1024x1024 App Store icon: FITA target with heatmap overlay."""
import random
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
OUT = Path(__file__).parent.parent.parent / "Sources/BowPress/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png"

# match target_face.png palette
BG = (250, 248, 242)
RINGS = [
    (0.95, (103, 195, 224)),  # blue outer
    (0.75, (228, 58, 58)),    # red
    (0.45, (250, 233, 98)),   # yellow
]
LINE = (0, 0, 0, 110)


def draw_target(img):
    d = ImageDraw.Draw(img, "RGBA")
    cx = cy = SIZE // 2
    outer_r = int(SIZE * 0.46)

    # base blue ring via outermost fill
    d.ellipse((cx - outer_r, cy - outer_r, cx + outer_r, cy + outer_r), fill=RINGS[0][1])

    # inner rings
    for pct, color in RINGS[1:]:
        r = int(outer_r * pct)
        d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=color)

    # thin separation lines (6 concentric)
    for i in range(6):
        r = int(outer_r * (0.15 + i * 0.14))
        d.ellipse((cx - r, cy - r, cx + r, cy + r), outline=LINE, width=3)

    # outer target border
    d.ellipse((cx - outer_r, cy - outer_r, cx + outer_r, cy + outer_r), outline=(0, 0, 0, 180), width=5)


def draw_heatmap(img):
    """Overlay a glow-dot heatmap cluster representing arrow impacts."""
    overlay = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)

    # cluster in the gold zone biased slightly high-right (2 o'clock)
    cx, cy = SIZE // 2 + 30, SIZE // 2 - 40
    random.seed(42)
    for _ in range(80):
        dx = int(random.gauss(0, 55))
        dy = int(random.gauss(0, 55))
        x, y = cx + dx, cy + dy
        r = random.randint(22, 46)
        # hot color — yellow-white core fading to orange
        intensity = max(0, 255 - int((abs(dx) + abs(dy)) * 0.8))
        color = (255, 220, 80, intensity // 2)
        d.ellipse((x - r, y - r, x + r, y + r), fill=color)

    overlay = overlay.filter(ImageFilter.GaussianBlur(18))

    # discrete impact points on top for definition
    d2 = ImageDraw.Draw(overlay)
    for _ in range(14):
        dx = int(random.gauss(0, 45))
        dy = int(random.gauss(0, 45))
        x, y = cx + dx, cy + dy
        r = random.randint(7, 12)
        d2.ellipse((x - r, y - r, x + r, y + r), fill=(40, 30, 20, 235))

    img.alpha_composite(overlay)


def main():
    img = Image.new("RGBA", (SIZE, SIZE), BG)
    draw_target(img)
    draw_heatmap(img)
    rgb = Image.new("RGB", (SIZE, SIZE), BG)  # flatten alpha — App Store forbids it
    rgb.paste(img, mask=img.split()[3])
    OUT.parent.mkdir(parents=True, exist_ok=True)
    rgb.save(OUT, "PNG", optimize=True)
    print(f"wrote {OUT}  ({OUT.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
