from PIL import Image, ImageDraw
import os
sizes = [48,72,96,144,192]
for size in sizes:
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    for i in range(size // 2, 0, -1):
        alpha = int(240 * (1 - i / (size / 2)))
        draw.ellipse([size/2-i, size/2-i, size/2+i, size/2+i], fill=(23, 120, 245, alpha))
    stroke = max(4, size // 15)
    draw.line([(size*0.08, size*0.42), (size*0.48, size*0.23), (size*0.84, size*0.28)], fill=(255,255,255,220), width=stroke)
    draw.line([(size*0.04, size*0.58), (size*0.46, size*0.37), (size*0.82, size*0.42)], fill=(255,255,255,185), width=stroke)
    draw.line([(size*0.12, size*0.74), (size*0.52, size*0.52), (size*0.86, size*0.55)], fill=(255,255,255,155), width=stroke)
    draw.polygon([(size*0.16, size*0.86), (size*0.42, size*0.58), (size*0.75, size*0.62), (size*0.92, size*0.86)], fill=(255,255,255,140))
    m = 'mdpi' if size == 48 else 'hdpi' if size == 72 else 'xhdpi' if size == 96 else 'xxhdpi' if size == 144 else 'xxxhdpi'
    path = f'android/app/src/main/res/mipmap-{m}/ic_launcher.png'
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)
    print('saved', path)
