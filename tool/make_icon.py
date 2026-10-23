# Erzeugt alle App-Symbole aus einer Vorlage ("Wackelpudding": gewölbtes Play-Zeichen
# aus Gelee auf dunklem Grund, mit Glanz und Wackel-Linien):
#   - windows/runner/resources/app_icon.ico und assets/app_icon.ico (16–256 px)
#   - assets/icon.png (512 px, in der App)
#   - macos/Runner/Assets.xcassets/AppIcon.appiconset (16–1024 px, nach Apples Raster:
#     824 px Fläche auf 1024 px, mit Schatten)
# Start:  python3 tool/make_icon.py   (braucht Pillow und numpy: pip3 install pillow numpy)
import io
import struct
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SS = 6  # Überabtastung für glatte Kanten

# --- Vorlage in einem 100×100-Raster ---------------------------------------------

SQUIRCLE_EXPONENT = 5  # Superellipse |x|^n + |y|^n = 1 – die übliche App-Symbol-Form
JELLY = [('M', (33, 25)), ('Q', (25, 50), (33, 75)), ('Q', (58, 72), (79, 51)), ('Q', (59, 29), (33, 25))]
JELLY_STROKE = 7  # abgerundete Kanten (wie stroke-linejoin: round)
HIGHLIGHT = [('M', (34, 31)), ('Q', (30, 42), (31, 50)), ('Q', (42, 37), (60, 36)), ('Q', (48, 31), (34, 31))]
WOBBLES = [([(86, 42), (90, 50), (86, 58)], 1.0), ([(92, 37), (98, 50), (92, 63)], 0.5)]

BG_TOP, BG_BOTTOM = (31, 27, 56), (12, 11, 22)
JELLY_STOPS = [(0.0, (192, 132, 252)), (0.5, (139, 92, 246)), (1.0, (6, 182, 212))]
WOBBLE_COLOR = (196, 181, 253)
SHADOW_COLOR = (139, 92, 246)


def path_points(path, steps=64):
    pts = []
    for cmd, *args in path:
        if cmd == 'M':
            pts.append(args[0])
            continue
        p0 = pts[-1]
        for i in range(1, steps + 1):
            t = i / steps
            if cmd == 'Q':
                (c, p1) = args
                x = (1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * c[0] + t ** 2 * p1[0]
                y = (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * c[1] + t ** 2 * p1[1]
            else:
                (c1, c2, p1) = args
                x = ((1 - t) ** 3 * p0[0] + 3 * (1 - t) ** 2 * t * c1[0] + 3 * (1 - t) * t ** 2 * c2[0]
                     + t ** 3 * p1[0])
                y = ((1 - t) ** 3 * p0[1] + 3 * (1 - t) ** 2 * t * c1[1] + 3 * (1 - t) * t ** 2 * c2[1]
                     + t ** 3 * p1[1])
            pts.append((x, y))
    return pts


def squircle_points(steps=720):
    pts = []
    for i in range(steps):
        a = 2 * np.pi * i / steps
        c, si = np.cos(a), np.sin(a)
        x = np.sign(c) * abs(c) ** (2 / SQUIRCLE_EXPONENT)
        y = np.sign(si) * abs(si) ** (2 / SQUIRCLE_EXPONENT)
        pts.append((50 + 50 * x, 50 + 50 * y))
    return pts


def mask(size, points, scale, offset, grow=0.0):
    """Gefüllte Form; [grow] erweitert sie rundum (runde Ecken) um so viele Rastereinheiten."""
    m = Image.new('L', (size, size), 0)
    d = ImageDraw.Draw(m)
    xy = [(offset + x * scale, offset + y * scale) for x, y in points]
    d.polygon(xy, fill=255)
    if grow:
        r = grow * scale
        d.line(xy + [xy[0]], fill=255, width=round(2 * r), joint='curve')
        for x, y in xy[::4]:
            d.ellipse((x - r, y - r, x + r, y + r), fill=255)
    return m


def linear(size, box, start, end, stops):
    """Linearer Verlauf über [box] (x0, y0, x1, y1) von [start] nach [end] (relativ zur Box)."""
    x0, y0, x1, y1 = box
    sx, sy = x0 + start[0] * (x1 - x0), y0 + start[1] * (y1 - y0)
    ex, ey = x0 + end[0] * (x1 - x0), y0 + end[1] * (y1 - y0)
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    dx, dy = ex - sx, ey - sy
    t = np.clip(((xx - sx) * dx + (yy - sy) * dy) / (dx * dx + dy * dy), 0, 1)
    out = np.zeros((size, size, 4), np.float32)
    out[..., 3] = 255
    for ch in range(3):
        out[..., ch] = np.interp(t, [s[0] for s in stops], [s[1][ch] for s in stops])
    return Image.fromarray(out.astype(np.uint8))


def bbox(points, scale, offset):
    xs = [offset + x * scale for x, _ in points]
    ys = [offset + y * scale for _, y in points]
    return min(xs), min(ys), max(xs), max(ys)


def render(px, mac=False):
    """Symbol mit [px] Kantenlänge. [mac]: nach Apples Raster mit Rand und Schatten."""
    s = px * SS
    area = s * 824 / 1024 if mac else s
    off = (s - area) / 2
    k = area / 100
    small = px <= 32
    img = Image.new('RGBA', (s, s), (0, 0, 0, 0))

    squircle = squircle_points()
    if mac:
        shadow = Image.new('RGBA', (s, s), (0, 0, 0, 0))
        shadow.paste((0, 0, 0, 110), (0, round(s * 0.012)), mask(s, squircle, k, off))
        img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(s * 0.014)))

    # Dunkler Grund (Verlauf von oben nach unten).
    bg_mask = mask(s, squircle, k, off)
    bg = linear(s, bbox(squircle, k, off), (0, 0), (0, 1), [(0, BG_TOP), (1, BG_BOTTOM)])
    img.paste(bg, (0, 0), bg_mask)
    layer = Image.new('RGBA', (s, s), (0, 0, 0, 0))

    # Leuchtender Schatten unter dem Gelee.
    if not small:
        glow = Image.new('RGBA', (s, s), (0, 0, 0, 0))
        ImageDraw.Draw(glow).ellipse((off + 30 * k, off + 77 * k, off + 74 * k, off + 85 * k),
                                     fill=SHADOW_COLOR + (140,))
        layer.alpha_composite(glow.filter(ImageFilter.GaussianBlur(2.5 * k)))

    # Gelee-Play mit Verlauf.
    jelly = path_points(JELLY)
    grow = JELLY_STROKE / 2
    jelly_mask = mask(s, jelly, k, off, grow=grow)
    x0, y0, x1, y1 = bbox(jelly, k, off)
    jbox = (x0 - grow * k, y0 - grow * k, x1 + grow * k, y1 + grow * k)
    layer.paste(linear(s, jbox, (0.15, 0), (0.85, 1), JELLY_STOPS), (0, 0), jelly_mask)

    # Glanzlicht oben links.
    if px >= 24:
        hl = path_points(HIGHLIGHT)
        hl_box = bbox(hl, k, off)
        shine = linear(s, hl_box, (0, 0), (0, 1), [(0, (255, 255, 255)), (1, (255, 255, 255))])
        alpha = linear(s, hl_box, (0, 0), (0, 1), [(0, (178, 178, 178)), (1, (0, 0, 0))]).getchannel('R')
        alpha = Image.fromarray(np.minimum(np.array(alpha), np.array(mask(s, hl, k, off))))
        layer.paste(shine, (0, 0), alpha)

    # Wackel-Linien rechts neben der Spitze.
    if not small:
        d = ImageDraw.Draw(layer)
        for (a, c, b), opacity in WOBBLES:
            pts = path_points([('M', a), ('Q', c, b)], 32)
            xy = [(off + x * k, off + y * k) for x, y in pts]
            color = WOBBLE_COLOR + (round(255 * opacity),)
            w = 3 * k
            d.line(xy, fill=color, width=round(w), joint='curve')
            for x, y in (xy[0], xy[-1]):
                d.ellipse((x - w / 2, y - w / 2, x + w / 2, y + w / 2), fill=color)

    # Alles außerhalb der Fläche abschneiden (Wackel-Linien reichen bis an den Rand).
    clipped = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    clipped.paste(layer, (0, 0), Image.fromarray(np.minimum(np.array(layer.getchannel('A')), np.array(bg_mask))))
    img.alpha_composite(clipped)
    return img.resize((px, px), Image.LANCZOS)


def write_ico(path, sizes):
    images = []
    for size in sizes:
        buf = io.BytesIO()
        render(size).save(buf, 'PNG')
        images.append((size, buf.getvalue()))
    out = io.BytesIO()
    out.write(struct.pack('<HHH', 0, 1, len(images)))
    offset = 6 + 16 * len(images)
    for size, data in images:
        dim = 0 if size >= 256 else size
        out.write(struct.pack('<BBBBHHII', dim, dim, 0, 0, 1, 32, len(data), offset))
        offset += len(data)
    for _, data in images:
        out.write(data)
    path.write_bytes(out.getvalue())


if __name__ == '__main__':
    ico_sizes = [16, 24, 32, 48, 64, 128, 256]
    write_ico(ROOT / 'windows' / 'runner' / 'resources' / 'app_icon.ico', ico_sizes)
    write_ico(ROOT / 'assets' / 'app_icon.ico', ico_sizes)
    render(512).save(ROOT / 'assets' / 'icon.png')
    mac = ROOT / 'macos' / 'Runner' / 'Assets.xcassets' / 'AppIcon.appiconset'
    for size in (16, 32, 64, 128, 256, 512, 1024):
        render(size, mac=True).save(mac / f'app_icon_{size}.png')
    print('Symbole geschrieben: Windows (.ico), assets/icon.png, macOS (AppIcon.appiconset)')
