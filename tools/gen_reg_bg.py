from PIL import Image, ImageDraw
import os
size = (1080, 1920)
img = Image.new('RGBA', size, (235, 245, 255, 255))
draw = ImageDraw.Draw(img)
draw.rectangle([0, 0, size[0], size[1]], fill=(235, 245, 255, 255))
draw.ellipse([size[0] * 0.1, size[1] * 0.15, size[0] * 0.95, size[1] * 0.65], fill=(222, 236, 255, 255))
draw.polygon([
    (size[0] * 0.06, size[1] * 0.82),
    (size[0] * 0.12, size[1] * 0.28),
    (size[0] * 0.32, size[1] * 0.05),
    (size[0] * 0.26, size[1] * 0.92)
], fill=(217, 233, 252, 255))
draw.polygon([
    (size[0] * 0.8, size[1] * 0.7),
    (size[0] * 0.6, size[1] * 0.24),
    (size[0] * 0.98, size[1] * 0.16),
    (size[0] * 0.94, size[1] * 0.88)
], fill=(207, 222, 250, 255))
draw.ellipse([size[0] * 0.12, size[1] * 0.08, size[0] * 0.36, size[1] * 0.2], fill=(185, 214, 255, 255))
draw.ellipse([size[0] * 0.58, size[1] * 0.24, size[0] * 0.84, size[1] * 0.38], fill=(190, 220, 255, 255))
draw.ellipse([size[0] * 0.35, size[1] * 0.55, size[0] * 0.86, size[1] * 0.78], fill=(232, 242, 255, 255))
for i, color in enumerate([(255, 255, 255, 200), (255, 255, 255, 160), (255, 255, 255, 120)]):
    y = size[1] * 0.7 + i * 20
    draw.line([(size[0] * 0.15, y), (size[0] * 0.5, size[1] * 0.55 + i * 20), (size[0] * 0.78, size[1] * 0.6 + i * 20)], fill=color, width=28)
os.makedirs('assets/images', exist_ok=True)
img.save('assets/images/registration_background.png')
print('saved assets/images/registration_background.png')
