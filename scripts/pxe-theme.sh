#!/usr/bin/env bash
# ==============================================================================
# ProxPXE - Gerenciador de Tema (Lê configurações do theme.ini) (100% Bash)
# Padrão Visual: Claro (Branco e Azul - Hospital Regional Menino Jesus)
# ==============================================================================

set -eo pipefail

THEME_DIR="${THEME_DIR:-/data/theme}"
FONTS_DIR="$THEME_DIR/fonts"
ICONS_DIR="$THEME_DIR/icons"
TFTP_THEME="${TFTP_THEME:-/var/lib/tftpboot/theme}"
CONFIG_DIR="${CONFIG_DIR:-/data/config}"
INI_FILE="$CONFIG_DIR/theme.ini"

# Fallback se theme.ini não estiver em /data/config
if [ ! -f "$INI_FILE" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [ -f "$SCRIPT_DIR/../configs/theme.ini" ]; then
        INI_FILE="$SCRIPT_DIR/../configs/theme.ini"
    fi
fi

# Função auxiliar para ler chaves do .ini
get_ini() {
    local key="$1"
    local default="$2"
    local val=""
    if [ -f "$INI_FILE" ]; then
        val=$(grep -E "^[[:space:]]*$key[[:space:]]*=" "$INI_FILE" 2>/dev/null | head -n1 | cut -d'=' -f2- | tr -d '"' | tr -d "'" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    fi
    echo "${val:-$default}"
}

# Lê variáveis do .ini
FONT_FAMILY=$(get_ini "font_family" "Outfit")
FONT_SIZE=$(get_ini "font_size" "14")
BG_COLOR=$(get_ini "bg_color" "#f8fafc")
ITEM_COLOR=$(get_ini "item_color" "#334155")
SEL_ITEM_COLOR=$(get_ini "selected_item_color" "#ffffff")
HOTKEY_COLOR=$(get_ini "hotkey_color" "#64748b")
ORGANIZATION=$(get_ini "organization" "Hospital Regional Menino Jesus")

mkdir -p "$THEME_DIR" "$FONTS_DIR" "$ICONS_DIR"
if [ -d "/var/lib/tftpboot" ] || [ "$TFTP_THEME" != "/var/lib/tftpboot/theme" ]; then
    mkdir -p "$TFTP_THEME" 2>/dev/null || true
fi

echo "==> [PROXPXE-THEME] Carregando tema a partir de $INI_FILE..."
echo "    -> Organização: $ORGANIZATION"
echo "    -> Paleta: Branco e Azul Hospitalar | Fonte: $FONT_FAMILY ($FONT_SIZE)"

# 1. Converte fontes para .pf2 se grub-mkfont estiver disponível
if command -v grub-mkfont >/dev/null 2>&1; then
    # Converte Outfit.ttf se existir
    if [ -f "$FONTS_DIR/Outfit.ttf" ] && [ ! -f "$FONTS_DIR/Outfit.pf2" ]; then
        echo "    -> Convertendo Outfit.ttf para Outfit.pf2..."
        grub-mkfont -s "$FONT_SIZE" -o "$FONTS_DIR/Outfit.pf2" "$FONTS_DIR/Outfit.ttf" || true
    fi

    # Converte outras fontes
    for ttf in "$FONTS_DIR"/*.ttf "$FONTS_DIR"/*.otf; do
        [ -f "$ttf" ] || continue
        pf2_name="$(basename "${ttf%.*}").pf2"
        if [ ! -f "$FONTS_DIR/$pf2_name" ]; then
            echo "    -> Convertendo $ttf para $pf2_name..."
            grub-mkfont -s "$FONT_SIZE" -o "$FONTS_DIR/$pf2_name" "$ttf" || true
        fi
    done
fi

# 2. Localiza fonte ativa
ACTIVE_FONT="$FONT_FAMILY"
if [ ! -f "$FONTS_DIR/$ACTIVE_FONT.pf2" ]; then
    FIRST_PF2=$(find "$FONTS_DIR" -name "*.pf2" 2>/dev/null | head -n1 || true)
    if [ -n "$FIRST_PF2" ]; then
        ACTIVE_FONT=$(basename "${FIRST_PF2%.*}")
    fi
fi

# 3. Gera o arquivo theme.txt com cores claras (Branco e Azul Menino Jesus)
cat << EOF > "$THEME_DIR/theme.txt"
# ==========================================
# ProxPXE Ventoy-Style GRUB2 Theme
# Tema Claro: Branco e Azul ($ORGANIZATION)
# ==========================================

title-text: ""
desktop-image: "background.png"
desktop-color: "$BG_COLOR"
terminal-box: "terminal_box_*.png"

# Caixa Central de Menu Estilo Ventoy
+ boot_menu {
    left = 18%
    top = 28%
    width = 64%
    height = 54%
    item_font = "$ACTIVE_FONT $FONT_SIZE"
    item_color = "$ITEM_COLOR"
    selected_item_color = "$SEL_ITEM_COLOR"
    item_height = 38
    item_spacing = 4
    icon_width = 24
    icon_height = 24
    item_icon_space = 12
    selected_item_pixmap_style = "select_*.png"
    menu_pixmap_style = "box_*.png"
}

# Logo do Sistema no Topo (Hospital Menino Jesus)
+ image {
    left = 50%-145
    top = 8%
    width = 290
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

# Rodapé com Atalhos
+ label {
    left = 18%
    top = 89%
    width = 64%
    height = 24
    text = "[Enter] Iniciar  |  [e] Editar Parâmetros  |  [c] Console  |  $ORGANIZATION"
    font = "$ACTIVE_FONT 11"
    color = "$HOTKEY_COLOR"
    align = "center"
}
EOF

# 4. Sincroniza arquivos de tema com o TFTP
if [ -d "$TFTP_THEME" ]; then
    cp -r "$THEME_DIR"/* "$TFTP_THEME/" 2>/dev/null || true
fi

echo "==> [PROXPXE-THEME] Tema atualizado com sucesso a partir do theme.ini!"
