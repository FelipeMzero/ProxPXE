from PIL import Image, ImageDraw
import sys

W, H = 1920, 1080

# Gradiente base dark navy estilo Ventoy
img = Image.new('RGB', (W, H))
draw = ImageDraw.Draw(img)

for y in range(H):
    t = y / H
    r = int(10 + t * 2)
    g = int(15 + t * 3)
    b = int(35 + t * 5)
    draw.line([(0, y), (W, y)], fill=(r, g, b))

# Header bar
draw.rectangle([0, 0, W, 58], fill=(12, 22, 52))
draw.rectangle([0, 56, W, 60], fill=(37, 99, 235))  # accent line

# Footer bar
draw.rectangle([0, H-52, W, H], fill=(10, 18, 44))
draw.rectangle([0, H-53, W, H-50], fill=(30, 80, 200))  # accent line

# Painel central do menu
px1, py1 = 220, 68
px2, py2 = W-220, H-58

# Fundo do painel semi-transparente
pc = (14, 24, 52)
draw.rectangle([px1, py1, px2, py2], fill=pc)

# Borda azul brilhante
bc = (37, 99, 235)
draw.rectangle([px1, py1, px2, py1+2], fill=bc)
draw.rectangle([px1, py2-2, px2, py2], fill=bc)
draw.rectangle([px1, py1, px1+2, py2], fill=bc)
draw.rectangle([px2-2, py1, px2, py2], fill=bc)

# Sub-header (barra titulo interna)
draw.rectangle([px1+2, py1+2, px2-2, py1+44], fill=(20, 38, 84))
draw.rectangle([px1+2, py1+44, px2-2, py1+46], fill=(37, 99, 235))

# Listras zebra alternadas sutis (simula rows)
row_h = 50
for i in range(16):
    ry = py1 + 48 + i * row_h
    if ry + row_h < py2 - 2:
        if i % 2 == 0:
            draw.rectangle([px1+2, ry, px2-2, ry+row_h-1], fill=(16, 28, 58))

img.save('data/theme/background.png', 'PNG', optimize=True)
print('Background 1920x1080 OK')
