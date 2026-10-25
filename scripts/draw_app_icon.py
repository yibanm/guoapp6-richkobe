import argparse
from pathlib import Path

from PIL import Image, ImageDraw

root = Path(__file__).resolve().parents[1]
SIZE = 1024
GOLD = (253, 185, 39)
PURPLE_DARK = (58, 29, 92)
BG_TOP = (85, 37, 131)
BG_BOTTOM = (46, 21, 72)
BALL_CENTER = (512, 512)
BALL_RADIUS = 300
LINE_WIDTH = 24


def lerp_color(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def bezier(p0, p1, p2, steps=96):
    points = []
    for i in range(steps + 1):
        t = i / steps
        u = 1 - t
        points.append((
            u * u * p0[0] + 2 * u * t * p1[0] + t * t * p2[0],
            u * u * p0[1] + 2 * u * t * p1[1] + t * t * p2[1],
        ))
    return points


def gradient_background(size=SIZE, top=BG_TOP, bottom=BG_BOTTOM):
    column = Image.new('RGB', (1, size))
    for y in range(size):
        column.putpixel((0, y), lerp_color(top, bottom, y / (size - 1)))
    return column.resize((size, size)).convert('RGBA')


def radial_fade_layer(size, center, radius, color, peak_alpha):
    layer = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    cx, cy = center
    for i in range(radius, 0, -2):
        alpha = int(peak_alpha * (1 - i / radius))
        draw.ellipse([cx - i, cy - i, cx + i, cy + i], fill=(*color, alpha))
    return layer


def rounded_triangle(draw, points, thickness, fill):
    draw.line(list(points) + [points[0]], fill=fill, width=thickness, joint='curve')
    draw.polygon(points, fill=fill)


def compose_master():
    canvas = gradient_background()
    cx, cy = BALL_CENTER
    r = BALL_RADIUS

    glow = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    for i in range(48, 0, -1):
        radius = r + i * 14
        alpha = max(1, int(26 * (1 - i / 48)))
        glow_draw.ellipse([cx - radius, cy - radius, cx + radius, cy + radius],
                          fill=(*GOLD, alpha))
    canvas.alpha_composite(glow)

    ball = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    ball_draw = ImageDraw.Draw(ball)
    ball_draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(*GOLD, 255))

    highlight = radial_fade_layer(SIZE, (cx - 110, cy - 130), 300, (255, 226, 130), 150)
    shadow = radial_fade_layer(SIZE, (cx + 150, cy + 170), 340, (160, 96, 10), 120)
    circle_mask = Image.new('L', (SIZE, SIZE), 0)
    ImageDraw.Draw(circle_mask).ellipse([cx - r, cy - r, cx + r, cy + r], fill=255)
    ball.paste(Image.alpha_composite(ball, highlight), (0, 0))
    shaded = Image.alpha_composite(ball, shadow)
    ball = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    ball.paste(shaded, (0, 0), circle_mask)

    lines = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    lines_draw = ImageDraw.Draw(lines)
    color = (*PURPLE_DARK, 255)
    lines_draw.line([(cx, cy - r), (cx, cy + r)], fill=color, width=LINE_WIDTH)
    lines_draw.line([(cx - r, cy), (cx + r, cy)], fill=color, width=LINE_WIDTH)
    dx = int(r * 0.5)
    dy = int(r * 0.866)
    bulge = int(r * 0.25)
    lines_draw.line(bezier((cx - dx, cy - dy), (cx + bulge, cy), (cx - dx, cy + dy)),
                    fill=color, width=LINE_WIDTH, joint='curve')
    lines_draw.line(bezier((cx + dx, cy - dy), (cx - bulge, cy), (cx + dx, cy + dy)),
                    fill=color, width=LINE_WIDTH, joint='curve')
    clipped_lines = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    clipped_lines.paste(lines, (0, 0), circle_mask)
    ball = Image.alpha_composite(ball, clipped_lines)

    play = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    play_draw = ImageDraw.Draw(play)
    triangle = [(466, 418), (466, 606), (630, 512)]
    shadow_layer = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    rounded_triangle(ImageDraw.Draw(shadow_layer),
                     [(x + 4, y + 14) for x, y in triangle], 52, (30, 12, 52, 90))
    canvas.alpha_composite(ball)
    canvas.alpha_composite(shadow_layer)
    rounded_triangle(play_draw, triangle, 52, (255, 255, 255, 255))
    canvas.alpha_composite(play)
    return canvas.convert('RGB')


def main():
    parser = argparse.ArgumentParser(
        description='绘制科比短剧图标母版（assets/app_icon_master.png）；平台资源分发用 generate_brand_assets.py。')
    parser.add_argument('--output', type=Path, default=root / 'assets/app_icon_master.png')
    parser.add_argument('--preview', type=Path, default=None,
                        help='额外输出一份预览副本，默认只写母版')
    options = parser.parse_args()
    icon = compose_master()
    options.output.parent.mkdir(parents=True, exist_ok=True)
    icon.save(options.output)
    print('母版已输出：', options.output)
    if options.preview:
        options.preview.parent.mkdir(parents=True, exist_ok=True)
        icon.save(options.preview)
        print('预览图已输出：', options.preview)


if __name__ == '__main__':
    main()
