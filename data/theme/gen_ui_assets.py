import os
from PIL import Image, ImageDraw

OUT_DIR = 'data/theme'
os.makedirs(OUT_DIR, exist_ok=True)

def create_slice(name, size, color, radius=0):
    img = Image.new('RGBA', size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    # Simple rectangle for slices (GRUB handles scaling)
    draw.rectangle([0, 0, size[0], size[1]], fill=color)
    img.save(os.path.join(OUT_DIR, name))

# Selection box (Estilo Ventoy: fundo azul vivo, sem borda complexa)
# RGBA: Azul brilhante
sel_color = (37, 99, 235, 255)
# Corners (c, n, e, s, w, ne, nw, se, sw)
create_slice('select_c.png', (16, 16), sel_color)
create_slice('select_n.png', (16, 4), sel_color)
create_slice('select_s.png', (16, 4), sel_color)
create_slice('select_e.png', (4, 16), sel_color)
create_slice('select_w.png', (4, 16), sel_color)
create_slice('select_ne.png', (4, 4), sel_color)
create_slice('select_nw.png', (4, 4), sel_color)
create_slice('select_se.png', (4, 4), sel_color)
create_slice('select_sw.png', (4, 4), sel_color)

# Progress Bar Background (Fundo escuro/cinza)
prog_bg = (20, 30, 60, 255)
create_slice('progress_bar_c.png', (16, 16), prog_bg)
create_slice('progress_bar_n.png', (16, 2), prog_bg)
create_slice('progress_bar_s.png', (16, 2), prog_bg)
create_slice('progress_bar_e.png', (2, 16), prog_bg)
create_slice('progress_bar_w.png', (2, 16), prog_bg)
create_slice('progress_bar_ne.png', (2, 2), prog_bg)
create_slice('progress_bar_nw.png', (2, 2), prog_bg)
create_slice('progress_bar_se.png', (2, 2), prog_bg)
create_slice('progress_bar_sw.png', (2, 2), prog_bg)

# Progress Bar Highlight (Preenchimento azul claro/ciano)
prog_fg = (56, 189, 248, 255)
create_slice('progress_highlight_c.png', (16, 16), prog_fg)
create_slice('progress_highlight_n.png', (16, 2), prog_fg)
create_slice('progress_highlight_s.png', (16, 2), prog_fg)
create_slice('progress_highlight_e.png', (2, 16), prog_fg)
create_slice('progress_highlight_w.png', (2, 16), prog_fg)
create_slice('progress_highlight_ne.png', (2, 2), prog_fg)
create_slice('progress_highlight_nw.png', (2, 2), prog_fg)
create_slice('progress_highlight_se.png', (2, 2), prog_fg)
create_slice('progress_highlight_sw.png', (2, 2), prog_fg)

print("UI Assets gerados com sucesso.")
