"""
Gerador de icones coloridos estilo Ventoy para GRUB2
Todos os icones 48x48 PNG RGBA com fundo transparente
"""
from PIL import Image, ImageDraw
import math, os

ICON_SIZE = 48
OUT_DIR = 'data/theme/icons'
os.makedirs(OUT_DIR, exist_ok=True)

def draw_rounded_rect(draw, bbox, radius, fill, outline=None, outline_width=2):
    x1, y1, x2, y2 = bbox
    draw.rectangle([x1+radius, y1, x2-radius, y2], fill=fill)
    draw.rectangle([x1, y1+radius, x2, y2-radius], fill=fill)
    for cx, cy in [(x1+radius, y1+radius),(x2-radius, y1+radius),(x1+radius, y2-radius),(x2-radius, y2-radius)]:
        draw.ellipse([cx-radius, cy-radius, cx+radius, cy+radius], fill=fill)
    if outline:
        for i in range(outline_width):
            draw.arc([x1+radius, y1, x1+2*radius, y1+2*radius], 180, 270, fill=outline)
            draw.arc([x2-2*radius, y1, x2-radius, y1+2*radius], 270, 360, fill=outline)
            draw.arc([x1+radius, y2-2*radius, x1+2*radius, y2-radius], 90, 180, fill=outline)
            draw.arc([x2-2*radius, y2-2*radius, x2-radius, y2-radius], 0, 90, fill=outline)

def new_icon():
    return Image.new('RGBA', (ICON_SIZE, ICON_SIZE), (0, 0, 0, 0))

def circle_icon(img, color, outline=None):
    d = ImageDraw.Draw(img)
    margin = 2
    if outline:
        d.ellipse([margin, margin, ICON_SIZE-margin, ICON_SIZE-margin], fill=outline)
        d.ellipse([margin+2, margin+2, ICON_SIZE-margin-2, ICON_SIZE-margin-2], fill=color)
    else:
        d.ellipse([margin, margin, ICON_SIZE-margin, ICON_SIZE-margin], fill=color)
    return d

# ========== UBUNTU (laranja) ==========
img = new_icon()
d = circle_icon(img, (233, 84, 32), (180, 60, 20))
# 3 dots no circulo ubuntu
angle_start = -30
for a in [angle_start, angle_start+120, angle_start+240]:
    rad = math.radians(a)
    cx = ICON_SIZE//2 + int(12 * math.cos(rad))
    cy = ICON_SIZE//2 + int(12 * math.sin(rad))
    d.ellipse([cx-4, cy-4, cx+4, cy+4], fill=(255,255,255,220))
img.save(f'{OUT_DIR}/ubuntu.png')

# ========== DEBIAN (vermelho) ==========
img = new_icon()
d = circle_icon(img, (215, 38, 56), (170, 20, 40))
# Espiral simplificada como D
cx, cy = ICON_SIZE//2, ICON_SIZE//2
d.arc([cx-10, cy-12, cx+12, cy+12], -60, 250, fill=(255,255,255,220), width=3)
d.ellipse([cx-3, cy-3, cx+3, cy+3], fill=(215,38,56,0))
img.save(f'{OUT_DIR}/debian.png')

# ========== PROXMOX (laranja escuro) ==========
img = new_icon()
d = circle_icon(img, (226, 88, 35), (180, 60, 15))
# Letra P estilizada
d.rectangle([cx-7, cy-12, cx-3, cy+12], fill=(255,255,255,230))
d.ellipse([cx-7, cy-12, cx+9, cy+2], fill=(255,255,255,230))
d.ellipse([cx-3, cy-8, cx+6, cy+0], fill=(226, 88, 35))
img.save(f'{OUT_DIR}/proxmox.png')

# ========== WINDOWS (azul microsoft) ==========
img = new_icon()
d = circle_icon(img, (0, 120, 212), (0, 80, 170))
# 4 quadrados windows
colors_w = [(0,188,242),(0,178,148),(255,185,0),(232,78,15)]
positions = [(cx-11, cy-11),(cx+2, cy-11),(cx-11, cy+2),(cx+2, cy+2)]
for (px, py), wc in zip(positions, colors_w):
    d.rectangle([px, py, px+8, py+8], fill=wc+(240,))
img.save(f'{OUT_DIR}/windows.png')

# ========== ARCH (azul ciano) ==========
img = new_icon()
d = circle_icon(img, (23, 147, 209), (10, 110, 170))
# Arco Arch (^)
d.polygon([(cx, cy-13), (cx-12, cy+10), (cx+12, cy+10)], fill=(255,255,255,0))
d.polygon([(cx, cy-13), (cx-12, cy+10), (cx-5, cy+10), (cx, cy-3), (cx+5, cy+10), (cx+12, cy+10)], fill=(255,255,255,220))
img.save(f'{OUT_DIR}/arch.png')

# ========== LINUX generico (amarelo pinguim) ==========
img = new_icon()
d = circle_icon(img, (50, 50, 60), (30, 30, 40))
# Pinguim simplificado - tux circle
d.ellipse([cx-7, cy-10, cx+7, cy+6], fill=(255,220,50))  # bico/peito
d.ellipse([cx-8, cy-12, cx+8, cy+8], fill=(255,255,255,200))
d.ellipse([cx-8, cy-12, cx+8, cy-2], fill=(40,40,40,230))
d.ellipse([cx-3, cy-9, cx+3, cy-5], fill=(255,165,0,240))
img.save(f'{OUT_DIR}/linux.png')

# ========== FEDORA (azul fedora) ==========
img = new_icon()
d = circle_icon(img, (60, 110, 180), (40, 80, 150))
# F de fedora
d.rectangle([cx-6, cy-12, cx-2, cy+12], fill=(255,255,255,230))
d.rectangle([cx-6, cy-12, cx+8, cy-8], fill=(255,255,255,230))
d.rectangle([cx-6, cy-2, cx+6, cy+2], fill=(255,255,255,230))
img.save(f'{OUT_DIR}/fedora.png')

# ========== RESCUE (vermelho/laranja) ==========
img = new_icon()
d = circle_icon(img, (220, 50, 50), (170, 20, 20))
# Cruz de primeiros socorros
d.rectangle([cx-3, cy-10, cx+3, cy+10], fill=(255,255,255,240))
d.rectangle([cx-10, cy-3, cx+10, cy+3], fill=(255,255,255,240))
img.save(f'{OUT_DIR}/rescue.png')

# ========== ISO generico (azul claro) ==========
img = new_icon()
d = circle_icon(img, (30, 80, 160), (15, 50, 130))
# Disco CD
d.ellipse([cx-12, cy-12, cx+12, cy+12], outline=(255,255,255,200), width=2)
d.ellipse([cx-4, cy-4, cx+4, cy+4], fill=(30,80,160), outline=(255,255,255,180), width=1)
img.save(f'{OUT_DIR}/iso.png')

# ========== NET (rede) ==========
img = new_icon()
d = circle_icon(img, (20, 160, 160), (10, 120, 120))
# Icone de rede (grade com linhas)
d.ellipse([cx-12, cy-4, cx+12, cy+4], outline=(255,255,255,200), width=2)
d.ellipse([cx-4, cy-12, cx+4, cy+12], fill=(0,0,0,0), outline=(255,255,255,200), width=2)
d.line([cx-13, cy, cx+13, cy], fill=(255,255,255,200), width=2)
d.line([cx, cy-13, cx, cy+13], fill=(255,255,255,200), width=2)
img.save(f'{OUT_DIR}/net.png')

# ========== PLAY (verde) ==========
img = new_icon()
d = circle_icon(img, (30, 160, 90), (15, 120, 60))
d.polygon([(cx-6, cy-10), (cx+10, cy), (cx-6, cy+10)], fill=(255,255,255,230))
img.save(f'{OUT_DIR}/play.png')

# ========== RAM (roxo) ==========
img = new_icon()
d = circle_icon(img, (120, 60, 200), (80, 30, 160))
# Placa de memoria
d.rectangle([cx-12, cy-5, cx+12, cy+5], fill=(255,255,255,220))
for x in [cx-9, cx-5, cx-1, cx+3, cx+7]:
    d.rectangle([x, cy-9, x+2, cy-5], fill=(255,255,255,220))
    d.rectangle([x, cy+5, x+2, cy+9], fill=(255,255,255,220))
img.save(f'{OUT_DIR}/ram.png')

# ========== RESTART (azul) ==========
img = new_icon()
d = circle_icon(img, (40, 100, 220), (20, 70, 180))
# Circulo com seta (restart)
d.arc([cx-10, cy-10, cx+10, cy+10], 30, 300, fill=(255,255,255,230), width=3)
d.polygon([(cx+7, cy-12), (cx+13, cy-6), (cx+1, cy-8)], fill=(255,255,255,230))
img.save(f'{OUT_DIR}/restart.png')

# ========== SHUTDOWN (vermelho) ==========
img = new_icon()
d = circle_icon(img, (200, 40, 40), (150, 15, 15))
# Power icon
d.arc([cx-10, cy-6, cx+10, cy+12], 40, 320, fill=(255,255,255,230), width=3)
d.line([cx, cy-12, cx, cy+2], fill=(255,255,255,230), width=3)
img.save(f'{OUT_DIR}/shutdown.png')

# ========== TOOL (cinza) ==========
img = new_icon()
d = circle_icon(img, (80, 90, 110), (50, 60, 80))
# Chave inglesa
d.rectangle([cx-3, cy-12, cx+3, cy+12], fill=(255,255,255,220))
d.ellipse([cx-8, cy-14, cx+8, cy-4], fill=(255,255,255,220))
d.rectangle([cx-6, cy-12, cx+6, cy-6], fill=(80,90,110))
img.save(f'{OUT_DIR}/tool.png')

# ========== CANCEL (cinza escuro) ==========
img = new_icon()
d = circle_icon(img, (80, 80, 90), (50, 50, 60))
# X de cancelar
d.line([cx-8, cy-8, cx+8, cy+8], fill=(255,255,255,220), width=3)
d.line([cx+8, cy-8, cx-8, cy+8], fill=(255,255,255,220), width=3)
img.save(f'{OUT_DIR}/cancel.png')

# ========== LOCAL / HDD (cinza azulado) ==========
img = new_icon()
d = circle_icon(img, (45, 65, 100), (25, 45, 80))
# HD retangulo com parafuso
d.rectangle([cx-11, cy-7, cx+11, cy+7], fill=(255,255,255,210))
d.rectangle([cx-9, cy-5, cx+9, cy+5], fill=(45,65,100))
d.ellipse([cx-2, cy-2, cx+2, cy+2], fill=(255,255,255,200))
d.rectangle([cx-2, cy-7, cx+2, cy-5], fill=(255,255,255,210))  # leitura
img.save(f'{OUT_DIR}/hdd.png')

# ========== BLANK (invisivel) ==========
img = Image.new('RGBA', (ICON_SIZE, ICON_SIZE), (0, 0, 0, 0))
img.save(f'{OUT_DIR}/blank.png')

# ========== LOCAL (igual HDD) ==========
import shutil
shutil.copy(f'{OUT_DIR}/hdd.png', f'{OUT_DIR}/local.png')

print(f'Todos os {len(os.listdir(OUT_DIR))} icones 48x48 gerados em {OUT_DIR}')
