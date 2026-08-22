#!/usr/bin/env python3
"""程序化生成 ShadowDepths UI 石质 9-slice 外框与圆形插槽纹理。"""
from PIL import Image, ImageDraw, ImageFilter
import os
import random

random.seed(42)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEX_DIR = os.path.join(ROOT, "godot", "textures")
os.makedirs(TEX_DIR, exist_ok=True)


def add_noise(draw, size, density, low, high):
    w, h = size
    for _ in range(int(w * h * density)):
        x = random.randint(0, w - 1)
        y = random.randint(0, h - 1)
        r = random.randint(low, high)
        draw.point((x, y), fill=(r, r, r, 45))


def hex_color(hex_str):
    hex_str = hex_str.lstrip("#")
    return tuple(int(hex_str[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


STONE = (44, 34, 25, 255)
STONE_DARK = (28, 22, 16, 255)
BRASS = (176, 141, 79, 255)
BRASS_HI = (214, 182, 122, 255)
INK = (10, 8, 6, 255)


def gen_frame(out_path, size=256, margin=24):
    """石质 9-slice 外框：透明中心 + 窄 stone 边框 + 内嵌黄铜线 + 四角铆钉。"""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    s = size
    m = margin

    # 外框底色（stone）
    draw.rounded_rectangle([0, 0, s - 1, s - 1], radius=m // 2, fill=STONE)
    # 外框暗边（内侧阴影）
    draw.rounded_rectangle([2, 2, s - 3, s - 3], radius=m // 2 - 1, outline=STONE_DARK, width=2)
    # 内嵌黄铜线
    draw.rounded_rectangle([m - 2, m - 2, s - m + 1, s - m + 1], radius=4, outline=BRASS, width=2)
    # 黄铜高光线
    draw.rounded_rectangle([m - 1, m - 1, s - m, s - m], radius=4, outline=BRASS_HI, width=1)
    # 中心透明挖空
    draw.rounded_rectangle([m, m, s - m - 1, s - m - 1], radius=3, fill=(0, 0, 0, 0))

    # 四角铆钉
    rivet_r = max(4, m // 5)
    positions = [
        (m + 2, m + 2),
        (s - m - 3, m + 2),
        (m + 2, s - m - 3),
        (s - m - 3, s - m - 3),
    ]
    for cx, cy in positions:
        draw.ellipse([cx - rivet_r, cy - rivet_r, cx + rivet_r, cy + rivet_r], fill=BRASS)
        draw.ellipse([cx - rivet_r + 1, cy - rivet_r + 1, cx + rivet_r - 1, cy + rivet_r - 1], outline=BRASS_HI, width=1)

    # 噪点
    add_noise(draw, (s, s), 0.25, 20, 70)
    img = img.filter(ImageFilter.GaussianBlur(radius=0.3))
    img.save(out_path, "PNG")
    print("Saved", out_path, "margin=", margin)


def gen_socket(out_path, size=128):
    """圆形深凹插槽：深色中心 + 黄铜环 + 内阴影。"""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    c = size // 2
    r_outer = size // 2 - 2
    r_inner = size // 2 - 10

    # 外阴影
    for i in range(4):
        off = 3 - i
        draw.ellipse([c - r_outer + off, c - r_outer + off, c + r_outer + off, c + r_outer + off],
                     fill=(0, 0, 0, 40))
    # 主凹槽（stone 深）
    draw.ellipse([c - r_outer, c - r_outer, c + r_outer, c + r_outer], fill=(35, 28, 22, 255))
    # 黄铜环
    draw.ellipse([c - r_inner - 2, c - r_inner - 2, c + r_inner + 2, c + r_inner + 2], outline=BRASS, width=2)
    draw.ellipse([c - r_inner, c - r_inner, c + r_inner, c + r_inner], outline=BRASS_HI, width=1)
    # 中心深色
    draw.ellipse([c - r_inner, c - r_inner, c + r_inner, c + r_inner], fill=INK)
    # 左上高光（凹陷感）
    draw.arc([c - r_inner + 4, c - r_inner + 4, c + r_inner - 4, c + r_inner - 4],
             start=160, end=300, fill=(255, 240, 200, 35), width=2)
    add_noise(draw, (size, size), 0.18, 20, 60)
    img.save(out_path, "PNG")
    print("Saved", out_path)


def gen_vignette(out_path, size=256):
    """低血暗角：白色径向 alpha 蒙版（中心透明、边缘不透明），运行时用 modulate 染红。"""
    img = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    c = size / 2.0
    inner = c * 0.50
    outer = c
    for y in range(size):
        for x in range(size):
            d = ((x - c) ** 2 + (y - c) ** 2) ** 0.5
            if d <= inner:
                a = 0
            else:
                t = min(1.0, (d - inner) / (outer - inner))
                a = int(t * 255)
            img.putpixel((x, y), (255, 255, 255, a))
    img = img.filter(ImageFilter.GaussianBlur(radius=max(1, size // 48)))
    img.save(out_path, "PNG")
    print("Saved", out_path, "vignette")


if __name__ == "__main__":
    gen_frame(os.path.join(TEX_DIR, "frame.png"), margin=24)
    gen_socket(os.path.join(TEX_DIR, "socket.png"))
    gen_vignette(os.path.join(TEX_DIR, "vignette.png"))
