"""Original deterministic surface sets: albedo, tangent normal and roughness.

v6 changes over v5:
  * normals are derived from a dedicated height field instead of albedo
    luminance, so colour patterns no longer fake relief;
  * a cheap ambient-occlusion term is baked into albedo, so seams, grooves
    and carved runes actually read as recessed;
  * roughness carries per-pixel variation and gets rougher in crevices.
"""
from pathlib import Path
import math, random
from PIL import Image

ROOT = Path(__file__).resolve().parents[1] / 'assets' / 'textures'
ROOT.mkdir(parents=True, exist_ok=True)
KINDS = ['stone', 'soil', 'wood', 'cloth', 'metal', 'leather', 'skin', 'bone', 'roof', 'bark',
         'scales', 'runes', 'chainmail', 'embroidery', 'rust', 'fur', 'chitin', 'glass', 'marble',
         'parchment', 'copper', 'moss']
N = 256
# How strongly the height field displaces the surface normal.
RELIEF = {'stone': 3.0, 'soil': 1.4, 'wood': 2.2, 'cloth': 1.2, 'metal': 1.8, 'leather': 1.6,
          'skin': 0.8, 'bone': 1.4, 'roof': 3.4, 'bark': 3.0, 'scales': 3.2, 'runes': 2.6,
          'chainmail': 3.6, 'embroidery': 1.6, 'rust': 2.0, 'fur': 1.8, 'chitin': 2.8,
          'glass': 2.0, 'marble': 0.7, 'parchment': 0.9, 'copper': 2.0, 'moss': 2.4}


def box_blur(grid, n, radius):
    """Separable wrap-around blur used to approximate ambient occlusion."""
    span = 2 * radius + 1
    tmp = [[0.0] * n for _ in range(n)]
    for y in range(n):
        row = grid[y]
        for x in range(n):
            s = 0.0
            for k in range(-radius, radius + 1):
                s += row[(x + k) % n]
            tmp[y][x] = s / span
    out = [[0.0] * n for _ in range(n)]
    for y in range(n):
        for x in range(n):
            s = 0.0
            for k in range(-radius, radius + 1):
                s += tmp[(y + k) % n][x]
            out[y][x] = s / span
    return out


for kind in KINDS:
    rng = random.Random('embers-v6-' + kind)
    values, colors, rough, heights = [], [], [], []
    scratches = {(rng.randrange(N), rng.randrange(N)) for _ in range(160)}
    for y in range(N):
        row, crow, rrow, hrow = [], [], [], []
        for x in range(N):
            broad = math.sin(x * math.tau / 64) * math.cos(y * math.tau / 128)
            v = .86 + rng.uniform(-.045, .045) + .035 * broad
            tint = (1, 1, 1)
            r = .85
            h = v  # height defaults to the albedo level unless overridden below
            if kind == 'stone':
                seam = y % 32 < 2 or (x + (32 if (y // 32) % 2 else 0)) % 64 < 2
                if seam:
                    v *= .47; h = .30
                elif y % 32 == 2:
                    v *= 1.13; h = .95
                if (x // 64 + y // 32) % 5 == 0: v *= .9
                h = h * .8 + .2 * (.5 + .5 * math.sin(x * .21) * math.cos(y * .17))
            elif kind in ('wood', 'bark'):
                grain = math.sin(x * .6 + math.sin(y * math.tau / 128) * 2)
                v += .06 * grain
                if x % 32 < 2: v *= .56
                if kind == 'bark' and grain < -.65: v *= .7
                h = .80 + .10 * grain - (.32 if x % 32 < 2 else 0.0)
                if kind == 'bark' and grain < -.65: h -= .22
            elif kind in ('cloth', 'embroidery'):
                v *= .90 + .10 * ((x + y) % 2)
                h = .55 + .06 * ((x % 4 < 2) != (y % 4 < 2))
                if kind == 'embroidery':
                    pattern = (x % 64 < 5 or y % 64 < 5 or abs(x % 64 - y % 64) < 2
                               or abs(x % 64 + y % 64 - 64) < 2)
                    if pattern:
                        v = .95; tint = (1, .88, .65); h = .92
                    else:
                        v *= .70; tint = (.8, .85, 1); h = .48
            elif kind in ('metal', 'rust', 'copper'):
                v += .045 * math.sin(x * .11); r = .38
                h = .62 + .05 * math.sin(x * .11) + .04 * math.cos(y * .19)
                if (x, y) in scratches or (x - 1, y - 1) in scratches:
                    v *= .52; r = .8; h = .30
                if kind == 'rust' and math.sin(x * .10) * math.cos(y * .12) > .28:
                    v *= .67; tint = (1, .61, .35); r = .95; h = .42
                if kind == 'copper' and broad > .1:
                    tint = (.45, .88, .78); r = .8
            elif kind == 'leather':
                v *= .95 + .035 * math.sin(x * .8) * math.cos(y * .8)
                h = .58 + .10 * math.sin(x * .27) * math.cos(y * .23)
                if x % 64 in (3, 4) and y % 8 < 4: v = .99; h = .88
                if x % 64 < 2: v *= .6; h = .26
            elif kind == 'skin':
                v = .91 + rng.uniform(-.025, .025) + broad * .025
                tint = (1, .96, .93); r = .72
                h = .60 + .05 * math.sin(x * .35) * math.cos(y * .31)
            elif kind == 'bone':
                v = .92 + rng.uniform(-.025, .025) + .035 * math.cos(x * .15)
                tint = (1, .98, .91)
                h = .66 + .06 * math.cos(x * .15)
                if x % 64 == 13 and y % 97 < 30: v *= .65; h = .32
            elif kind == 'roof':
                if y % 32 < 2 or (x + 16 * (y // 32 % 2)) % 32 < 2:
                    v *= .48; h = .26
                elif y % 32 < 5:
                    v *= 1.10; h = .92
                else:
                    h = .70 + .12 * math.sin(y * .4)
                v *= .90 + .10 * (y % 32) / 32
            elif kind in ('scales', 'chitin'):
                tilex = (x + 8 * (y // 16 % 2)) % 16
                tiley = y % 16
                dome = max(0.0, 1 - math.hypot(tilex - 8, tiley - 5) / 12)
                v *= .72 + .28 * dome
                h = .34 + .60 * dome * dome
                if tiley > 13: v *= .72; h = .30
                if kind == 'chitin':
                    r = .48; tint = (.91, .98, 1)
            elif kind == 'chainmail':
                tx = (x + 6 * (y // 10 % 2)) % 12
                ty = y % 10
                dist = math.hypot((tx - 6) / 5, (ty - 5) / 3.5)
                if .68 < dist < 1.1:
                    v = .98 if ty < 5 else .84
                    h = .95 if ty < 5 else .74   # upper half of each ring catches light
                else:
                    v = .31; h = .18
                r = .58
            elif kind == 'fur':
                v += .035 * math.sin(x * .9 + math.sin(y * .1))
                if (x + (y // 12) * 3) % 13 < 2: v *= .88
                tint = (1, .97, .90)
                h = .50 + .22 * math.sin(x * .9 + math.sin(y * .1))
                if (x + (y // 12) * 3) % 13 < 2: h -= .18
            elif kind == 'runes':
                pattern = ((x % 64 in (16, 17, 48, 49) and 16 <= y % 64 <= 49)
                           or (y % 64 in (16, 17, 32, 33) and 16 <= x % 64 <= 49))
                if pattern:
                    v = .96; tint = (.95, .90, 1); h = .30   # engraved, sits below the surface
                else:
                    v *= .62; h = .74
            elif kind == 'glass':
                lead = abs(x % 64 - y % 64) < 3 or abs(x % 64 + y % 64 - 64) < 3
                if lead:
                    v = .23; h = .92
                else:
                    v = .94; h = .60
                tint = [(.51, .68, 1), (1, .66, .39), (.71, .84, .55)][(x // 32 + y // 32) % 3]
                r = .15
            elif kind == 'marble':
                v = .9 + .03 * broad
                vein = abs(math.sin(x * .06 + math.sin(y * .05))) < .08
                if vein: v = .57
                r = .42
                h = .72 - (.22 if vein else 0) + .03 * math.sin(y * .3)
            elif kind == 'parchment':
                v = .9 + broad * .045; tint = (1, .93, .77)
                h = .60 + .05 * math.sin(x * .13) * math.cos(y * .11)
            elif kind == 'moss':
                v = .72 + broad * .16; tint = (.82, 1, .70)
                h = .42 + .26 * abs(math.sin(x * .5) * math.cos(y * .43))
            else:
                v += broad * .07
                h = .60 + .14 * math.sin(x * .18) * math.cos(y * .22) + .06 * broad
            row.append(max(.05, min(1, v)))
            crow.append(tint)
            rrow.append(r)
            hrow.append(max(.05, min(1, h)))
        values.append(row); colors.append(crow); rough.append(rrow); heights.append(hrow)

    blurred = box_blur(heights, N, 2)
    relief = RELIEF.get(kind, 2.0)
    albedo = Image.new('RGB', (N, N))
    normal = Image.new('RGB', (N, N))
    roughness = Image.new('L', (N, N))
    for y in range(N):
        for x in range(N):
            v = values[y][x]
            tint = colors[y][x]
            h = heights[y][x]
            # Concave pixels sit below their neighbourhood average and get darkened.
            ao = max(.45, min(1.08, .62 + .38 * (h + .06) / (blurred[y][x] + .06)))
            v = max(.05, min(1, v * (.42 + .58 * ao)))
            albedo.putpixel((x, y), tuple(int(v * 255 * c) for c in tint))
            dx = (heights[y][(x + 1) % N] - heights[y][(x - 1) % N]) * relief
            dy = (heights[(y + 1) % N][x] - heights[(y - 1) % N][x]) * relief
            z = 1 / math.sqrt(dx * dx + dy * dy + 1)
            normal.putpixel((x, y), (int((-dx * z * .5 + .5) * 255),
                                     int((dy * z * .5 + .5) * 255),
                                     int((z * .5 + .5) * 255)))
            rr = rough[y][x] + rng.uniform(-.05, .05) + (1.0 - ao) * .18
            roughness.putpixel((x, y), int(max(.05, min(1, rr)) * 255))
    albedo.save(ROOT / f'{kind}.png')
    normal.save(ROOT / f'{kind}_normal.png')
    roughness.save(ROOT / f'{kind}_roughness.png')

print(f'Generated {len(KINDS)} original {N}px PBR sets ({len(KINDS) * 3} maps) with height normals and baked AO')
