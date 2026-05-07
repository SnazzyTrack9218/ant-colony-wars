#!/usr/bin/env python3
"""
Generate placeholder PNG assets for Ant Colony Wars.

Run from the project root:
    python tools/generate_placeholders.py

Re-run any time to regenerate. Real art replaces these by dropping a file with
the same name into the same folder — no code changes needed.
"""

from PIL import Image, ImageDraw, ImageFont
import pathlib

# ── font setup ────────────────────────────────────────────────────────────────

def _load_font(size):
    for path in [
        "C:/Windows/Fonts/arial.ttf",
        "C:/Windows/Fonts/verdana.ttf",
        "C:/Windows/Fonts/segoeui.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "/Library/Fonts/Arial.ttf",
    ]:
        try:
            return ImageFont.truetype(path, size)
        except Exception:
            pass
    return ImageFont.load_default()

FONT_SM = _load_font(8)
FONT_MD = _load_font(11)
FONT_LG = _load_font(13)


# ── helpers ───────────────────────────────────────────────────────────────────

def _save(img, rel_path):
    p = pathlib.Path(rel_path)
    p.parent.mkdir(parents=True, exist_ok=True)
    img.save(str(p), "PNG")
    print(f"  {rel_path}")


def _centered(draw, size, text, font):
    """Return (x, y) to draw text centered inside size=(w, h)."""
    try:
        bb = draw.textbbox((0, 0), text, font=font)
        tw, th = bb[2] - bb[0], bb[3] - bb[1]
    except AttributeError:
        tw, th = draw.textsize(text, font=font)
    return (size[0] - tw) // 2, (size[1] - th) // 2


def _darker(rgb, amount=70):
    return tuple(max(0, c - amount) for c in rgb)


# ── ant generator ─────────────────────────────────────────────────────────────
#
#  3-segment body: head (top) → thorax (mid) → abdomen (bottom)
#  antennae, 3 leg pairs, optional crown for queen
#  All drawn on 32×32 transparent canvas

def _ant(body_rgb, head_rgb=None, crown=False, big=False):
    w, h = 32, 32
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    if head_rgb is None:
        head_rgb = _darker(body_rgb, 35)

    ol  = _darker(body_rgb, 90) + (255,)
    abd = body_rgb + (255,)
    hd  = head_rgb + (255,)
    cx  = w // 2

    # Abdomen — large oval at bottom
    aw = 10 if big else 9
    d.ellipse([cx - aw, 17, cx + aw, 31], fill=abd, outline=ol, width=1)

    # Petiole — tiny waist node
    d.ellipse([cx - 2, 13, cx + 2, 19], fill=hd, outline=ol, width=1)

    # Thorax
    tw = 6 if big else 5
    d.ellipse([cx - tw, 10, cx + tw, 17], fill=hd, outline=ol, width=1)

    # Head
    hw = 6 if big else 5
    d.ellipse([cx - hw,  1, cx + hw, 12], fill=hd, outline=ol, width=1)

    # Antennae
    d.line([cx - 2, 3, cx - 7,  0], fill=ol, width=1)
    d.line([cx + 2, 3, cx + 7,  0], fill=ol, width=1)

    # Legs — 3 pairs from thorax zone
    for dy in [-1, 1, 3]:
        ty = 13 + dy
        d.line([cx - tw, ty, cx - 13, ty + 4], fill=ol, width=1)
        d.line([cx + tw, ty, cx + 13, ty + 4], fill=ol, width=1)

    # Crown dots for queen
    if crown:
        for px in [cx - 4, cx, cx + 4]:
            d.ellipse([px - 1, 0, px + 1, 2], fill=(255, 220, 0, 255))

    return img


def _egg():
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([8, 6, 24, 26], fill=(245, 245, 215, 255),
              outline=(190, 185, 140, 255), width=1)
    # Subtle shine dot
    d.ellipse([12, 9, 15, 12], fill=(255, 255, 245, 200))
    return img


# ── tile generator ────────────────────────────────────────────────────────────

def _dirt_tile():
    img = Image.new("RGBA", (16, 16), (135, 100, 22, 255))
    d = ImageDraw.Draw(img)
    # Scattered darker specks for texture
    for x, y in [(2, 2), (7, 4), (11, 3), (4, 9), (13, 7), (3, 13), (9, 12), (14, 11)]:
        d.point((x, y), fill=(95, 65, 10, 255))
    # Lighter crumbs
    for x, y in [(5, 6), (10, 9), (2, 11)]:
        d.point((x, y), fill=(165, 130, 45, 255))
    d.rectangle([0, 0, 15, 15], outline=(88, 60, 8, 255), width=1)
    return img


def _tunnel_tile():
    """Near-black — represents dug-out empty space."""
    img = Image.new("RGBA", (16, 16), (16, 9, 4, 255))
    d = ImageDraw.Draw(img)
    # Faint texture so it's not pure black
    for x, y in [(3, 3), (10, 7), (6, 13), (13, 11)]:
        d.point((x, y), fill=(30, 18, 8, 255))
    d.rectangle([0, 0, 15, 15], outline=(38, 22, 10, 255), width=1)
    return img


def _stone_tile():
    img = Image.new("RGBA", (16, 16), (118, 118, 122, 255))
    d = ImageDraw.Draw(img)
    # Crack lines suggestion
    d.line([(3, 2), (7, 6)],  fill=(80, 80, 84, 255), width=1)
    d.line([(10, 8), (13, 13)], fill=(80, 80, 84, 255), width=1)
    # Highlight flecks
    for x, y in [(5, 5), (12, 4), (8, 11)]:
        d.point((x, y), fill=(145, 145, 150, 255))
    d.rectangle([0, 0, 15, 15], outline=(70, 70, 75, 255), width=1)
    return img


# ── room generator ────────────────────────────────────────────────────────────

def _room(bg_rgb, label, label_rgb=None):
    w, h = 64, 64
    if label_rgb is None:
        # auto pick light or dark label based on perceived brightness
        brightness = 0.299 * bg_rgb[0] + 0.587 * bg_rgb[1] + 0.114 * bg_rgb[2]
        label_rgb = (20, 20, 20) if brightness > 128 else (230, 230, 230)

    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    border = _darker(bg_rgb, 60)

    # Main fill with thick border
    d.rectangle([0, 0, w - 1, h - 1], fill=bg_rgb + (255,),
                outline=border + (255,), width=3)

    # Inner lighter border for depth
    lighter = tuple(min(255, c + 30) for c in bg_rgb)
    d.rectangle([3, 3, w - 4, h - 4], outline=lighter + (80,), width=1)

    # Centered label text
    x, y = _centered(d, (w, h), label, FONT_LG)
    # Shadow
    d.text((x + 1, y + 1), label, fill=(0, 0, 0, 100), font=FONT_LG)
    d.text((x, y), label, fill=label_rgb + (255,), font=FONT_LG)

    return img


# ── enemy generator ───────────────────────────────────────────────────────────

def _spider(rgb=(175, 10, 10)):
    """8-legged round body."""
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    ol   = _darker(rgb, 70) + (255,)
    fill = rgb + (255,)

    # Body
    d.ellipse([8, 10, 24, 24], fill=fill, outline=ol, width=1)
    # Smaller head
    d.ellipse([12, 4, 20, 13], fill=fill, outline=ol, width=1)
    # Eyes
    d.ellipse([13, 6, 15, 8], fill=(0, 0, 0, 255))
    d.ellipse([17, 6, 19, 8], fill=(0, 0, 0, 255))
    # 8 legs (4 per side)
    for i, (ly, lox) in enumerate([(11, 3), (14, 2), (17, 2), (20, 3)]):
        d.line([8,  ly, 8  - lox - i, ly - 3 + i * 2], fill=ol, width=1)
        d.line([24, ly, 24 + lox + i, ly - 3 + i * 2], fill=ol, width=1)
    return img


def _beetle(rgb=(50, 28, 5)):
    """Wide oval body with shell-split line."""
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    ol    = _darker(rgb, 20) + (255,)
    fill  = rgb + (255,)
    shine = tuple(min(255, c + 40) for c in rgb) + (255,)

    # Wide oval body
    d.ellipse([3, 9, 29, 27], fill=fill, outline=ol, width=1)
    # Shell highlight
    d.ellipse([6, 11, 16, 25], fill=shine, outline=None)
    # Center split
    d.line([16, 9, 16, 27], fill=ol, width=1)
    # Small round head
    d.ellipse([11, 4, 21, 13], fill=fill, outline=ol, width=1)
    # Short antennae
    d.line([13, 5, 10, 1], fill=ol, width=1)
    d.line([19, 5, 22, 1], fill=ol, width=1)
    # Legs
    for ly in [13, 17, 21]:
        d.line([3, ly, 0, ly + 3], fill=ol, width=1)
        d.line([29, ly, 32, ly + 3], fill=ol, width=1)
    return img


def _termite(rgb=(155, 88, 28)):
    """Pale elongated worker-termite body."""
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    ol   = _darker(rgb, 55) + (255,)
    fill = rgb + (255,)
    hd   = _darker(rgb, 20) + (255,)

    # Long oval body
    d.ellipse([10, 6, 22, 28], fill=fill, outline=ol, width=1)
    # Round head
    d.ellipse([10, 2, 22, 12], fill=hd, outline=ol, width=1)
    # Antennae
    d.line([13, 4, 9, 0],  fill=ol, width=1)
    d.line([19, 4, 23, 0], fill=ol, width=1)
    # Legs
    for ly in [13, 17, 21]:
        d.line([10, ly, 5,  ly + 2], fill=ol, width=1)
        d.line([22, ly, 27, ly + 2], fill=ol, width=1)
    return img


# ── UI icon generator ─────────────────────────────────────────────────────────

def _ui_icon(bg_rgb, symbol):
    w, h = 32, 32
    brightness = 0.299 * bg_rgb[0] + 0.587 * bg_rgb[1] + 0.114 * bg_rgb[2]
    txt_col = (20, 20, 20, 255) if brightness > 128 else (230, 230, 230, 255)

    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    border = _darker(bg_rgb, 60) + (255,)

    d.rectangle([1, 1, w - 2, h - 2], fill=bg_rgb + (255,),
                outline=border, width=2)
    x, y = _centered(d, (w, h), symbol, FONT_MD)
    d.text((x + 1, y + 1), symbol, fill=(0, 0, 0, 80), font=FONT_MD)
    d.text((x, y), symbol, fill=txt_col, font=FONT_MD)
    return img


# ── GENERATE ALL ──────────────────────────────────────────────────────────────

def generate_all():
    print("Generating placeholder assets...\n")

    print("Ants (32x32):")
    _save(_ant((200, 125, 22)),                          "assets/sprites/ants/worker_ant.png")
    _save(_ant((130, 0, 0),   head_rgb=(90, 0, 0)),     "assets/sprites/ants/soldier_ant.png")
    _save(_ant((212, 175, 0), head_rgb=(175, 140, 0), crown=True, big=True),
                                                         "assets/sprites/ants/queen_ant.png")
    _save(_egg(),                                        "assets/sprites/ants/egg.png")

    print("\nTiles (16x16):")
    _save(_dirt_tile(),   "assets/sprites/tiles/dirt_tile.png")
    _save(_tunnel_tile(), "assets/sprites/tiles/tunnel_tile.png")
    _save(_stone_tile(),  "assets/sprites/tiles/stone_tile.png")

    print("\nRooms (64x64):")
    _save(_room((218, 178, 0),   "QUEEN"),              "assets/sprites/rooms/queen_chamber.png")
    _save(_room((34, 139, 34),   "NURSERY"),            "assets/sprites/rooms/nursery.png")
    _save(_room((210, 110, 0),   "FOOD"),               "assets/sprites/rooms/food_storage.png")
    _save(_room((139, 0, 0),     "BARRACKS"),           "assets/sprites/rooms/soldier_barracks.png")
    _save(_room((110, 0, 150),   "SHROOM"),             "assets/sprites/rooms/mushroom_farm.png")
    _save(_room((88, 88, 88),    "GUARD"),              "assets/sprites/rooms/guard_post.png")

    print("\nEnemies (32x32):")
    _save(_spider(), "assets/sprites/enemies/spider_enemy.png")
    _save(_beetle(), "assets/sprites/enemies/beetle_enemy.png")
    _save(_termite(),"assets/sprites/enemies/termite_enemy.png")

    print("\nUI icons (32x32):")
    _save(_ui_icon((50, 185, 50),  "FOOD"), "assets/sprites/ui/food_icon.png")
    _save(_ui_icon((200, 125, 22), "WRK"),  "assets/sprites/ui/worker_icon.png")
    _save(_ui_icon((139, 0, 0),    "SOL"),  "assets/sprites/ui/soldier_icon.png")
    _save(_ui_icon((210, 205, 165),"EGG"),  "assets/sprites/ui/egg_icon.png")

    print(f"\nDone. 20 placeholder assets saved.")
    print("To replace any asset: drop a same-named PNG in the same folder.")
    print("Godot auto-imports it on next startup. No code changes needed.")


if __name__ == "__main__":
    generate_all()
