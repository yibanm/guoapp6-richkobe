import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description='从统一图形生成科比短剧各平台资源；需要 Pillow。')
parser.add_argument('--icon', type=Path, default=root / 'assets/app_icon_master.png')
parser.add_argument('--output', type=Path, default=root)
parser.add_argument('--font', type=Path, default=None)
options = parser.parse_args()
output = options.output
icon = Image.open(options.icon).convert('RGB')


def find_cjk_font():
    candidates = [
        Path('/System/Library/Fonts/PingFang.ttc'),
        Path('C:/Windows/Fonts/msyhbd.ttc'),
        Path('C:/Windows/Fonts/msyh.ttc'),
        Path('/usr/share/fonts/truetype/wqy/wqy-microhei.ttc'),
    ]
    for candidate in candidates:
        if candidate.is_file():
            return str(candidate)
    raise SystemExit('未找到可用的中文字体，请用 --font 指定。')


def save(image, name):
    destination = output / name
    destination.parent.mkdir(parents=True, exist_ok=True)
    image.save(destination)


contents = json.loads((root / 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json').read_text())
for entry in contents['images']:
    if 'filename' in entry:
        size = round(float(entry['size'].split('x')[0]) * float(entry['scale'].rstrip('x')))
        save(icon.resize((size, size), Image.Resampling.LANCZOS),
             'ios/Runner/Assets.xcassets/AppIcon.appiconset/' + entry['filename'])
save(icon.resize((256, 256), Image.Resampling.LANCZOS), 'windows/runner/resources/app_icon.ico')
save(icon.resize((1024, 1024), Image.Resampling.LANCZOS), 'android/app/src/main/res/drawable/app_icon.png')
for density, size in [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96), ('xxhdpi', 144), ('xxxhdpi', 192)]:
    save(icon.resize((size, size), Image.Resampling.LANCZOS),
         f'android/app/src/main/res/mipmap-{density}/ic_launcher.png')
font = ImageFont.truetype(find_cjk_font() if options.font is None else str(options.font), 76)
banner = Image.new('RGB', (640, 360), '#101114')
banner.paste(icon.resize((180, 180), Image.Resampling.LANCZOS), (44, 90))
draw = ImageDraw.Draw(banner)
draw.text((255, 128), '科比短剧', font=font, fill='white')
save(banner, 'android/app/src/main/res/drawable-xhdpi/tv_banner.png')
