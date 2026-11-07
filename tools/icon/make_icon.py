"""Dessine l'icône de Grimoire (grimoire fermé, violet nuit et or).

Usage : python tools/icon/make_icon.py app/assets/launcher
Produit icon.png (fond plein) et foreground.png (icône adaptative Android, fond transparent).
"""
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw

BG = (27, 22, 38)
COVER = (74, 46, 140)
COVER_DARK = (52, 32, 102)
GOLD = (232, 199, 122)
PAGES = (243, 233, 216)
S = 4  # suréchantillonnage


def star(d, cx, cy, r_out, r_in, fill, points=4):
    pts = []
    for i in range(points * 2):
        a = math.pi / points * i - math.pi / 2
        r = r_out if i % 2 == 0 else r_in
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    d.polygon(pts, fill=fill)


def book(d, size, scale):
    """Dessine le livre centré ; scale = part de la largeur occupée."""
    w = size * scale * 0.72
    h = w * 1.3
    x0 = (size - w) / 2 - w * 0.03
    y0 = (size - h) / 2
    x1, y1 = x0 + w, y0 + h
    t = w * 0.06  # épaisseur des pages
    r = w * 0.05
    # tranche des pages (à droite et en bas)
    d.rounded_rectangle([x0 + t, y0 + t, x1 + t, y1 + t * 0.6], radius=r, fill=PAGES)
    for i in range(1, 4):
        yy = y0 + t + (h - t) * i / 4
        d.line([(x1 + t * 0.15, yy), (x1 + t * 0.9, yy)], fill=(214, 200, 176), width=max(1, int(w * 0.006)))
    # couverture
    d.rounded_rectangle([x0, y0, x1, y1], radius=r, fill=COVER)
    # dos
    d.rounded_rectangle([x0, y0, x0 + w * 0.12, y1], radius=r, fill=COVER_DARK)
    lw = max(2, int(w * 0.018))
    for yy in (y0 + h * 0.12, y1 - h * 0.12):
        d.line([(x0 + w * 0.02, yy), (x0 + w * 0.10, yy)], fill=GOLD, width=lw)
    # cadre doré
    m = w * 0.1
    d.rounded_rectangle([x0 + w * 0.12 + m * 0.6, y0 + m, x1 - m, y1 - m], radius=r * 0.6, outline=GOLD, width=lw)
    # coins
    cs = w * 0.07
    for cx, cy in [(x0 + w * 0.12 + m * 0.6, y0 + m), (x1 - m, y0 + m), (x0 + w * 0.12 + m * 0.6, y1 - m), (x1 - m, y1 - m)]:
        star(d, cx, cy, cs, cs * 0.3, GOLD)
    # emblème : grande étoile à quatre branches entourée d'étincelles
    ex = (x0 + w * 0.12 + x1) / 2
    ey = (y0 + y1) / 2
    R = w * 0.24
    d.ellipse([ex - R * 0.62, ey - R * 0.62, ex + R * 0.62, ey + R * 0.62], outline=GOLD, width=lw)
    star(d, ex, ey, R, R * 0.22, GOLD)
    for ang, dist, rr in [(-35, 0.95, 0.16), (140, 0.9, 0.12), (60, 1.0, 0.1), (230, 1.05, 0.09)]:
        a = math.radians(ang)
        star(d, ex + R * dist * math.cos(a), ey + R * dist * math.sin(a), R * rr, R * rr * 0.3, GOLD)
    # fermoir
    d.rounded_rectangle([x1 - w * 0.03, ey - h * 0.06, x1 + t * 1.2, ey + h * 0.06], radius=w * 0.02, fill=GOLD)


def render(path, size, scale, background):
    big = size * S
    img = Image.new('RGBA', (big, big), BG + (255,) if background else (0, 0, 0, 0))
    book(ImageDraw.Draw(img), big, scale)
    img.resize((size, size), Image.LANCZOS).save(path)


if __name__ == '__main__':
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    render(out / 'icon.png', 1024, 0.84, True)
    render(out / 'foreground.png', 1024, 0.62, False)
    print('icônes écrites dans', out)
