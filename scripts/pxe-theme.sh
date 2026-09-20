#!/usr/bin/env bash
# ==============================================================================
# ProxPXE - Gerenciador de Tema Ventoy (Outfit Font Default) (100% Bash)
# ==============================================================================

set -eo pipefail

THEME_DIR="${THEME_DIR:-/data/theme}"
FONTS_DIR="$THEME_DIR/fonts"
ICONS_DIR="$THEME_DIR/icons"
TFTP_THEME="/var/lib/tftpboot/theme"

mkdir -p "$THEME_DIR" "$FONTS_DIR" "$ICONS_DIR" "$TFTP_THEME"

echo "==> [PROXPXE-THEME] Configurando tema Ventoy e fonte padrão Outfit..."

# 1. Converte a fonte padrão Outfit.ttf para Outfit.pf2 se disponível
if command -v grub-mkfont >/dev/null 2>&1; then
    # Converte Outfit.ttf prioritariamente
    if [ -f "$FONTS_DIR/Outfit.ttf" ] && [ ! -f "$FONTS_DIR/Outfit.pf2" ]; then
        echo "    -> Convertendo fonte Outfit.ttf para Outfit.pf2..."
        grub-mkfont -s 14 -o "$FONTS_DIR/Outfit.pf2" "$FONTS_DIR/Outfit.ttf" || true
    fi

    # Converte outras fontes .ttf
    for ttf in "$FONTS_DIR"/*.ttf "$FONTS_DIR"/*.otf; do
        [ -f "$ttf" ] || continue
        pf2_name="$(basename "${ttf%.*}").pf2"
        if [ ! -f "$FONTS_DIR/$pf2_name" ]; then
            echo "    -> Convertendo $ttf para $pf2_name..."
            grub-mkfont -s 14 -o "$FONTS_DIR/$pf2_name" "$ttf" || true
        fi
    done

    # Fallback caso Outfit não exista
    if [ ! -f "$FONTS_DIR/Outfit.pf2" ] && [ ! -f "$FONTS_DIR/unicode.pf2" ]; then
        if [ -f /usr/share/fonts/truetype/dejavu/DejaVuSans.ttf ]; then
            grub-mkfont -s 14 -o "$FONTS_DIR/unicode.pf2" /usr/share/fonts/truetype/dejavu/DejaVuSans.ttf || true
        fi
    fi
fi

# 2. Define a fonte ativa (Prioridade: Outfit -> unicode)
ACTIVE_FONT="Outfit"
if [ -f "$FONTS_DIR/Outfit.pf2" ]; then
    ACTIVE_FONT="Outfit"
elif [ -f "$FONTS_DIR/unicode.pf2" ]; then
    ACTIVE_FONT="unicode"
fi

# 3. Gera o arquivo theme.txt com layout do Ventoy
cat << EOF > "$THEME_DIR/theme.txt"
# ==========================================
# ProxPXE Ventoy-Style GRUB2 Theme
# Fonte Padrão: $ACTIVE_FONT
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
    left = 50%-140
    top = 8%
    width = 280
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

echo "==> [PROXPXE-THEME] Tema configurado com fonte $ACTIVE_FONT!"
