#!/usr/bin/env bash
# ==============================================================================
# PROXMOX PXE - GERENCIADOR DE TEMA VENTOY (GRUB2 THEME)
# 100% Bash Shell Script
# ==============================================================================

set -eo pipefail

THEME_DIR="${THEME_DIR:-/data/theme}"
FONTS_DIR="$THEME_DIR/fonts"
ICONS_DIR="$THEME_DIR/icons"
TFTP_THEME="/var/lib/tftpboot/theme"

mkdir -p "$THEME_DIR" "$FONTS_DIR" "$ICONS_DIR" "$TFTP_THEME"

echo "==> [PXE-THEME] Configurando tema Ventoy e fontes..."

# 1. Converte fontes .ttf para .pf2 se grub-mkfont estiver disponível
if command -v grub-mkfont >/dev/null 2>&1; then
    for ttf in "$FONTS_DIR"/*.ttf "$FONTS_DIR"/*.otf; do
        [ -f "$ttf" ] || continue
        pf2_name="$(basename "${ttf%.*}").pf2"
        if [ ! -f "$FONTS_DIR/$pf2_name" ]; then
            echo "    -> Convertendo fonte $ttf para $pf2_name..."
            grub-mkfont -s 14 -o "$FONTS_DIR/$pf2_name" "$ttf" || true
        fi
    done

    # Garante a existência de unicode.pf2 padrão
    if [ ! -f "$FONTS_DIR/unicode.pf2" ]; then
        if [ -f /usr/share/fonts/truetype/dejavu/DejaVuSans.ttf ]; then
            echo "    -> Gerando unicode.pf2 a partir de DejaVuSans..."
            grub-mkfont -s 14 -o "$FONTS_DIR/unicode.pf2" /usr/share/fonts/truetype/dejavu/DejaVuSans.ttf || true
        elif [ -f /usr/share/fonts/truetype/unifont/unifont.ttf ]; then
            echo "    -> Gerando unicode.pf2 a partir de Unifont..."
            grub-mkfont -s 14 -o "$FONTS_DIR/unicode.pf2" /usr/share/fonts/truetype/unifont/unifont.ttf || true
        fi
    fi
fi

# 2. Localiza a fonte ativa
ACTIVE_FONT="unicode"
FIRST_PF2=$(find "$FONTS_DIR" -name "*.pf2" 2>/dev/null | head -n1 || true)
if [ -n "$FIRST_PF2" ]; then
    ACTIVE_FONT=$(basename "${FIRST_PF2%.*}")
fi

# 3. Gera o arquivo theme.txt idêntico ao layout do Ventoy
cat << EOF > "$THEME_DIR/theme.txt"
# ==========================================
# ProxPXE Ventoy-Style GRUB2 Theme
# Gerado por pxe-theme.sh
# ==========================================

title-text: ""
desktop-image: "background.png"
desktop-color: "#090d16"
terminal-box: "terminal_box_*.png"

# Caixa Central de Menu Estilo Ventoy
+ boot_menu {
    left = 18%
    top = 28%
    width = 64%
    height = 54%
    item_font = "$ACTIVE_FONT 14"
    item_color = "#94a3b8"
    selected_item_color = "#ffffff"
    item_height = 38
    item_spacing = 4
    icon_width = 24
    icon_height = 24
    item_icon_space = 12
    selected_item_pixmap_style = "select_*.png"
    menu_pixmap_style = "box_*.png"
}

# Logo do Sistema no Topo
+ image {
    left = 50%-130
    top = 8%
    width = 260
    height = 68
    file = "logo.png"
}

# Barra de Progresso de Timeout
+ progress_bar {
    id = "__timeout__"
    left = 18%
    top = 85%
    width = 64%
    height = 6
    show_text = false
    bar_style = "progress_bar_*.png"
    highlight_style = "progress_highlight_*.png"
}

# Atalhos e Informações no Rodapé
+ label {
    left = 18%
    top = 89%
    width = 64%
    height = 24
    text = "[Enter] Iniciar Selecionado  |  [e] Editar Kernel  |  [c] Console GRUB  |  [Esc] Voltar"
    font = "$ACTIVE_FONT 11"
    color = "#64748b"
    align = "center"
}
EOF

# 4. Sincroniza arquivos de tema com o TFTP
if [ -d "$TFTP_THEME" ]; then
    cp -r "$THEME_DIR"/* "$TFTP_THEME/" 2>/dev/null || true
fi

echo "==> [PXE-THEME] Tema Ventoy atualizado com sucesso!"
