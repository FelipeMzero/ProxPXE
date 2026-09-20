#!/usr/bin/env bash
# ==============================================================================
# PROXMOX PXE - SCRIPT DE ESCANEAMENTO E GERAÇÃO DE MENUS VENTOY (GRUB2 & iPXE)
# 100% Bash Shell Script
# ==============================================================================

set -eo pipefail

ISO_DIR="${ISO_DIR:-/data/iso}"
EXTRACTED_DIR="${EXTRACTED_DIR:-/data/extracted}"
THEME_DIR="${THEME_DIR:-/data/theme}"
TFTP_DIR="${TFTP_DIR:-/var/lib/tftpboot}"
CONFIG_DIR="${CONFIG_DIR:-/data/config}"

GRUB_CFG="$TFTP_DIR/grub/grub.cfg"
IPXE_CFG="$TFTP_DIR/menu.ipxe"
JSON_OUT="$CONFIG_DIR/isos.json"

mkdir -p "$ISO_DIR" "$EXTRACTED_DIR" "$THEME_DIR" "$CONFIG_DIR" "$TFTP_DIR/grub"

# Detecta IP do servidor
SERVER_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "192.168.1.100")
SERVER_IP=${SERVER_IP:-"192.168.1.100"}

echo "==> [PXE-SCAN] Iniciando escaneamento de ISOs em $ISO_DIR..."

# Inicia cabeçalho do grub.cfg
cat << 'EOF' > "$GRUB_CFG"
# ====================================================
# PROXMOX PXE - MENU GRÁFICO ESTILO VENTOY (GRUB2)
# Gerado automaticamente pelo script pxe-scan.sh
# ====================================================

set default="0"
set timeout="15"

# Carrega módulos essenciais de rede e gráficos
insmod efinet
insmod tftp
insmod http
insmod all_video
insmod font
insmod gfxterm
insmod gfxmenu
insmod png

# Auto-detecta IP do Servidor PXE
if [ -n "$net_default_server" ]; then
    set pxe_server=$net_default_server
else
EOF

echo "    set pxe_server=$SERVER_IP" >> "$GRUB_CFG"

cat << 'EOF' >> "$GRUB_CFG"
fi

# Resolução de tela e terminal gráfico
set gfxmode=1920x1080,1024x768,auto
set gfxpayload=keep
terminal_output gfxterm

# Carrega Fontes e Tema Gráfico do Ventoy
if loadfont (http,$pxe_server)/theme/fonts/unicode.pf2 ; then
    set theme=(http,$pxe_server)/theme/theme.txt
    export theme
elif loadfont (tftp)/theme/fonts/unicode.pf2 ; then
    set theme=(tftp)/theme/theme.txt
    export theme
fi

# ====================================================
# LISTA DE IMAGENS ISO DETECTADAS
# ====================================================

EOF

# Inicia cabeçalho do iPXE
cat << EOF > "$IPXE_CFG"
#!ipxe
# PXE Ventoy Fallback Menu
set menu-timeout 15000
set submenu-timeout \${menu-timeout}

:start
menu Proxmox PXE Boot Menu (Ventoy Style)
item --gap --             --- Imagens ISO Disponíveis ---
EOF

# Prepara JSON
echo "[" > "$JSON_OUT"
FIRST_JSON=1
ISO_COUNT=0

# Loop em todas as ISOs
shopt -s nullglob nocaseglob
for iso_path in "$ISO_DIR"/*.iso "$ISO_DIR"/*.img; do
    [ -f "$iso_path" ] || continue
    
    ISO_COUNT=$((ISO_COUNT + 1))
    iso_name=$(basename "$iso_path")
    iso_lower=$(echo "$iso_name" | tr '[:upper:]' '[:lower:]')
    iso_slug=$(echo "$iso_name" | sed 's/[^a-zA-Z0-9_\-]/_/g')
    iso_size=$(du -m "$iso_path" | cut -f1)
    
    target_extract="$EXTRACTED_DIR/$iso_slug"
    mkdir -p "$target_extract"

    # Detecção de Sistema Operacional
    os_title="ISO: $iso_name"
    os_class="iso"
    os_type="generic"

    if [[ "$iso_lower" =~ proxmox|pve ]]; then
        os_title="Proxmox VE Installer ($iso_name)"
        os_class="proxmox"
        os_type="proxmox"
    elif [[ "$iso_lower" =~ ubuntu ]]; then
        os_title="Ubuntu Linux Live ($iso_name)"
        os_class="ubuntu"
        os_type="ubuntu"
    elif [[ "$iso_lower" =~ debian ]]; then
        os_title="Debian GNU/Linux ($iso_name)"
        os_class="debian"
        os_type="debian"
    elif [[ "$iso_lower" =~ win|windows ]]; then
        os_title="Microsoft Windows Installer ($iso_name)"
        os_class="windows"
        os_type="windows"
    elif [[ "$iso_lower" =~ clonezilla ]]; then
        os_title="Clonezilla Live Backup ($iso_name)"
        os_class="rescue"
        os_type="clonezilla"
    elif [[ "$iso_lower" =~ arch ]]; then
        os_title="Arch Linux Netboot ($iso_name)"
        os_class="arch"
        os_type="arch"
    elif [[ "$iso_lower" =~ rescue|gparted|hiren ]]; then
        os_title="Rescue / Repair Tool ($iso_name)"
        os_class="rescue"
        os_type="rescue"
    fi

    # Tenta extrair kernel/initrd se 7z ou xorriso estiver instalado
    vmlinuz_path=""
    initrd_path=""

    if command -v 7z >/dev/null 2>&1; then
        if [ ! -f "$target_extract/.extracted" ]; then
            echo "    -> Extraindo kernel/initrd de $iso_name para boot rápido HTTP..."
            7z x "$iso_path" -o"$target_extract" "boot*" "casper*" "live*" "isolinux*" -r -y >/dev/null 2>&1 || true
            touch "$target_extract/.extracted"
        fi
    fi

    # Procura kernel e initrd extraídos
    vmlinuz_file=$(find "$target_extract" -type f \( -name "vmlinuz*" -o -name "linux*" \) 2>/dev/null | head -n1 || true)
    initrd_file=$(find "$target_extract" -type f \( -name "initrd*" -o -name "initramfs*" \) 2>/dev/null | head -n1 || true)

    if [ -n "$vmlinuz_file" ] && [ -n "$initrd_file" ]; then
        rel_kernel=$(echo "$vmlinuz_file" | sed "s|^$EXTRACTED_DIR/||")
        rel_initrd=$(echo "$initrd_file" | sed "s|^$EXTRACTED_DIR/||")
    fi

    # --- Gera Entrada no GRUB2 ---
    cat << EOF >> "$GRUB_CFG"
menuentry "$os_title" --class $os_class --class gnu-linux --class os {
EOF

    if [ "$os_type" = "proxmox" ] && [ -n "${rel_kernel:-}" ]; then
        cat << EOF >> "$GRUB_CFG"
    echo "Carregando Proxmox VE via HTTP..."
    linux (http,\$pxe_server)/extracted/$rel_kernel vga=791 splash=silent ip=dhcp
    initrd (http,\$pxe_server)/extracted/$rel_initrd
EOF
    elif [ "$os_type" = "ubuntu" ] && [ -n "${rel_kernel:-}" ]; then
        cat << EOF >> "$GRUB_CFG"
    echo "Carregando Ubuntu Live HTTP..."
    linux (http,\$pxe_server)/extracted/$rel_kernel ip=dhcp url=http://\$pxe_server/iso/$iso_name ds=nocloud-net ---
    initrd (http,\$pxe_server)/extracted/$rel_initrd
EOF
    elif [ "$os_type" = "debian" ] && [ -n "${rel_kernel:-}" ]; then
        cat << EOF >> "$GRUB_CFG"
    echo "Carregando Debian Live..."
    linux (http,\$pxe_server)/extracted/$rel_kernel boot=live components fetch=http://\$pxe_server/iso/$iso_name
    initrd (http,\$pxe_server)/extracted/$rel_initrd
EOF
    elif [ "$os_type" = "clonezilla" ] && [ -n "${rel_kernel:-}" ]; then
        cat << EOF >> "$GRUB_CFG"
    echo "Carregando Clonezilla..."
    linux (http,\$pxe_server)/extracted/$rel_kernel boot=live config noswap edd=on nomodeset locales=pt_BR.UTF-8 keyboard-layouts=br fetch=http://\$pxe_server/iso/$iso_name
    initrd (http,\$pxe_server)/extracted/$rel_initrd
EOF
    elif [ "$os_type" = "windows" ]; then
        cat << EOF >> "$GRUB_CFG"
    echo "Iniciando Instalador Windows via iPXE Sanboot..."
    chainloader (http,\$pxe_server)/uefi/ipxe.efi
EOF
    else
        # Fallback genérico: Memdisk ou Sanboot
        cat << EOF >> "$GRUB_CFG"
    echo "Carregando $iso_name em RAM (Memdisk)..."
    linux16 (http,\$pxe_server)/memdisk iso raw
    initrd16 (http,\$pxe_server)/iso/$iso_name
EOF
    fi

    echo "}" >> "$GRUB_CFG"
    echo "" >> "$GRUB_CFG"

    # --- Gera Entrada no iPXE ---
    echo "item iso_$ISO_COUNT $os_title" >> "$IPXE_CFG"

    # --- Adiciona no JSON para o Painel Web ---
    if [ "$FIRST_JSON" -eq 0 ]; then
        echo "," >> "$JSON_OUT"
    fi
    FIRST_JSON=0
    cat << EOF >> "$JSON_OUT"
  {
    "filename": "$iso_name",
    "title": "$os_title",
    "size_mb": $iso_size,
    "os_type": "$os_type",
    "icon": "$os_class"
  }
EOF

done
shopt -u nullglob nocaseglob

echo "]" >> "$JSON_OUT"

# Rodapé de utilitários no GRUB2
cat << 'EOF' >> "$GRUB_CFG"
# Opções de Sistema e Ferramentas
submenu ">> Ferramentas e Opcoes Avancadas" --class tool {
    menuentry "Iniciar iPXE Shell / Sanboot" --class net {
        chainloader (http,$pxe_server)/uefi/ipxe.efi
    }
    menuentry "Reiniciar Computador" --class restart {
        reboot
    }
    menuentry "Desligar Computador" --class shutdown {
        halt
    }
}
EOF

# Rodapé do iPXE
cat << 'EOF' >> "$IPXE_CFG"
item --gap --             --- Opções do Sistema ---
item shell                iPXE Shell
item reboot               Reiniciar
item exit                 Sair para BIOS

choose --timeout ${menu-timeout} target && goto ${target}

:shell
shell
goto start

:reboot
reboot

:exit
exit
EOF

echo "==> [PXE-SCAN] Concluído! $ISO_COUNT ISOs registradas em $GRUB_CFG e $IPXE_CFG"
