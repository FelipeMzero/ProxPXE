#!/usr/bin/env bash
# ==============================================================================
# PROXMOX PXE - SCRIPT DE ESCANEAMENTO E GERAÇÃO DE MENUS VENTOY (GRUB2 & iPXE)
# 100% Bash Shell Script
# ==============================================================================

set -eo pipefail

ISO_DIR="${ISO_DIR:-/data/iso}"
PVE_ISO_DIR="${PVE_ISO_DIR:-/data/proxmox-iso}"
EXTRACTED_DIR="${EXTRACTED_DIR:-/data/extracted}"
THEME_DIR="${THEME_DIR:-/data/theme}"
TFTP_DIR="${TFTP_DIR:-/var/lib/tftpboot}"
CONFIG_DIR="${CONFIG_DIR:-/data/config}"

GRUB_CFG="$TFTP_DIR/grub/grub.cfg"
IPXE_CFG="$TFTP_DIR/menu.ipxe"
SYS_CFG="$TFTP_DIR/bios/pxelinux.cfg/default"
JSON_OUT="$CONFIG_DIR/isos.json"

mkdir -p "$ISO_DIR" "$PVE_ISO_DIR" "$EXTRACTED_DIR" "$THEME_DIR" "$CONFIG_DIR" \
         "$TFTP_DIR/grub" "$TFTP_DIR/uefi" "$TFTP_DIR/bios/pxelinux.cfg" "$TFTP_DIR/pxelinux.cfg"

# Detecta IP do servidor
SERVER_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "192.168.1.100")
SERVER_IP=${SERVER_IP:-"192.168.1.100"}

echo "==> [PXE-SCAN] Iniciando escaneamento de ISOs em $ISO_DIR e $PVE_ISO_DIR..."

# Inicia cabeçalho do pxelinux.cfg/default (BIOS Legacy)
cat << 'EOF' > "$SYS_CFG"
PATH bios/ /
UI vesamenu.c32
DEFAULT ventoy_grub
PROMPT 0
TIMEOUT 150
ONTIMEOUT ventoy_grub

MENU TITLE ProxPXE - Hospital Regional Menino Jesus (Ventoy Edition)
MENU BACKGROUND /theme/background.png
MENU RESOLUTION 1024 768

MENU COLOR screen       37;40   #00000000 #00000000 none
MENU COLOR border       30;44   #00000000 #00000000 none
MENU COLOR title        1;36;44 #ff1e40af #00000000 std
MENU COLOR sel          7;37;40 #ffffffff #ff2563eb all
MENU COLOR unsel        37;44   #ff334155 #00000000 std
MENU COLOR help         37;40   #ff64748b #00000000 std
MENU COLOR timeout      37;40   #ff64748b #00000000 std
MENU COLOR timeout_msg  37;40   #ff64748b #00000000 std

LABEL ventoy_grub
    MENU LABEL [>>] INICIAR INTERFACE VENTOY COMPLETA (GRUB2)
    KERNEL /grub/i386-pc/core.0

LABEL -
    MENU LABEL ----------------------------------------------------
    MENU DISABLE

LABEL -
    MENU LABEL  *** ISOs DISPONIVEIS (SELECAO DIRETA SYSLINUX) ***
    MENU DISABLE

EOF

# Inicia cabeçalho do grub.cfg
cat << 'EOF' > "$GRUB_CFG"
# ====================================================
# PROXPXE - MENU GRÁFICO ESTILO VENTOY (GRUB2)
# Gerado automaticamente pelo script pxe-scan.sh
# ====================================================

set default="0"
set timeout="15"

# Carrega módulos essenciais de rede e gráficos (UEFI e BIOS)
insmod pxe
insmod efinet
insmod tftp
insmod http
insmod all_video
insmod vbe
insmod vga
insmod video_bochs
insmod video_cirrus
insmod font
insmod gfxterm
insmod gfxmenu
insmod png
insmod test

# Auto-detecta IP do Servidor PXE
if [ -n "$net_default_server" ]; then
    set pxe_server=$net_default_server
else
EOF

echo "    set pxe_server=$SERVER_IP" >> "$GRUB_CFG"

cat << 'EOF' >> "$GRUB_CFG"
fi

# Carrega Fontes (Prioriza TFTP local com fallback em HTTP)
loadfont (tftp)/theme/fonts/Outfit.pf2
loadfont (tftp)/theme/fonts/Outfit-11.pf2
loadfont (tftp)/grub/fonts/Outfit.pf2
loadfont (tftp)/theme/fonts/unicode.pf2
loadfont (tftp)/grub/fonts/unicode.pf2
loadfont ($root)/theme/fonts/Outfit.pf2
loadfont ($root)/theme/fonts/unicode.pf2
loadfont (http,$pxe_server)/theme/fonts/Outfit.pf2
loadfont (http,$pxe_server)/theme/fonts/unicode.pf2

# Resolução de tela e terminal gráfico gfxterm
set gfxmode=1920x1080,1366x768,1024x768,800x600,auto
set gfxpayload=keep
terminal_output gfxterm

# Carrega e ativa Tema Gráfico do Ventoy
if [ -f (tftp)/theme/theme.txt ]; then
    set theme=(tftp)/theme/theme.txt
elif [ -f ($root)/theme/theme.txt ]; then
    set theme=($root)/theme/theme.txt
elif [ -f (http,$pxe_server)/theme/theme.txt ]; then
    set theme=(http,$pxe_server)/theme/theme.txt
else
    set theme=(tftp)/theme/theme.txt
fi
export theme

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

# Prepara JSON e targets do iPXE
echo "[" > "$JSON_OUT"
FIRST_JSON=1
ISO_COUNT=0
IPXE_TARGETS="/tmp/ipxe_targets_$$.tmp"
> "$IPXE_TARGETS"

# Garante permissões de leitura no diretório de ISOs
chmod -R o+rX "$ISO_DIR" "$PVE_ISO_DIR" 2>/dev/null || true

# Coleta ISOs tanto da pasta local quanto do Proxmox compartilhado
shopt -s nullglob nocaseglob
RAW_ISOS=()

# 1. Pasta local /data/iso
if [ -d "$ISO_DIR" ]; then
    while IFS= read -r f; do
        [ -f "$f" ] && RAW_ISOS+=("$f|Local|iso")
    done < <(find -L "$ISO_DIR" -type f \( -iname "*.iso" -o -iname "*.img" \) 2>/dev/null)
fi

# 2. Pasta Proxmox /data/proxmox-iso
if [ -d "$PVE_ISO_DIR" ]; then
    while IFS= read -r f; do
        [ -f "$f" ] && RAW_ISOS+=("$f|Proxmox|proxmox-iso")
    done < <(find -L "$PVE_ISO_DIR" -type f \( -iname "*.iso" -o -iname "*.img" \) 2>/dev/null)
fi

for item in "${RAW_ISOS[@]}"; do
    IFS='|' read -r iso_path iso_source http_dir <<< "$item"
    [ -f "$iso_path" ] || continue
    
    ISO_COUNT=$((ISO_COUNT + 1))
    iso_name=$(basename "$iso_path")
    if [ "$http_dir" = "proxmox-iso" ]; then
        rel_iso_url="${iso_path#$PVE_ISO_DIR/}"
    else
        rel_iso_url="${iso_path#$ISO_DIR/}"
    fi
    rel_iso_url=$(echo "$rel_iso_url" | sed 's#^/##')
    iso_lower=$(echo "$iso_name" | tr '[:upper:]' '[:lower:]')
    iso_slug=$(echo "$iso_name" | sed 's/[^a-zA-Z0-9_\-]/_/g')
    iso_size=$(du -m "$iso_path" | cut -f1 2>/dev/null || echo "0")
    
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

    # Tenta extrair dados mínimos de boot para carregamento rápido
    vmlinuz_path=""
    initrd_path=""

    if command -v 7z >/dev/null 2>&1; then
        if [ ! -f "$target_extract/.extracted" ]; then
            if [ "$os_type" = "windows" ]; then
                echo "    -> Extraindo bootloader WinPE de $iso_name (estilo Ventoy)..."
                7z x "$iso_path" -o"$target_extract" "bootmgr*" "boot/bcd" "boot/boot.sdi" "sources/boot.wim" -r -y >/dev/null 2>&1 || true
            else
                echo "    -> Extraindo kernel/initrd de $iso_name para boot rápido HTTP (estilo Ventoy)..."
                7z x "$iso_path" -o"$target_extract" "boot*" "casper*" "live*" "isolinux*" -r -y >/dev/null 2>&1 || true
            fi
            touch "$target_extract/.extracted"
        fi
    fi

    # Procura kernel e initrd extraídos
    vmlinuz_file=$(find "$target_extract" -type f \( -name "vmlinuz*" -o -name "linux*" \) 2>/dev/null | head -n1 || true)
    initrd_file=$(find "$target_extract" -type f \( -name "initrd*" -o -name "initramfs*" \) 2>/dev/null | head -n1 || true)

    rel_kernel=""
    rel_initrd=""
    if [ -n "$vmlinuz_file" ] && [ -n "$initrd_file" ]; then
        rel_kernel=$(echo "$vmlinuz_file" | sed "s|^$EXTRACTED_DIR/||")
        rel_initrd=$(echo "$initrd_file" | sed "s|^$EXTRACTED_DIR/||")
    fi

    if [ "$iso_size" -ge 1024 ]; then
        iso_size_str="$(awk -v s="$iso_size" 'BEGIN {printf "%.1f GB", s/1024}')"
    else
        iso_size_str="${iso_size} MB"
    fi

    # --- Gera Submenu no GRUB2 com os Modos de Boot do Ventoy ---
    cat << EOF >> "$GRUB_CFG"
submenu "$os_title ($iso_size_str) [$iso_source]" --class $os_class --class gnu-linux --class os {
    set default="0"
    set timeout="10"

    menuentry "-> [1] Iniciar em Modo Normal (Ventoy HTTP Live Stream)" --class play --class $os_class {
EOF

    if [ "$os_type" = "proxmox" ] && [ -n "${rel_kernel:-}" ]; then
        cat << EOF >> "$GRUB_CFG"
        echo "Iniciando Proxmox VE via HTTP (Modo Ventoy)..."
        linux (http,\$pxe_server)/extracted/$rel_kernel vga=791 splash=silent ip=dhcp proxmox-iso=http://\$pxe_server/$http_dir/$rel_iso_url
        initrd (http,\$pxe_server)/extracted/$rel_initrd
EOF
    elif [ "$os_type" = "ubuntu" ] && [ -n "${rel_kernel:-}" ]; then
        cat << EOF >> "$GRUB_CFG"
        echo "Iniciando Ubuntu Live via HTTP (Modo Ventoy)..."
        linux (http,\$pxe_server)/extracted/$rel_kernel ip=dhcp url=http://\$pxe_server/$http_dir/$rel_iso_url ds=nocloud-net ---
        initrd (http,\$pxe_server)/extracted/$rel_initrd
EOF
    elif [ "$os_type" = "debian" ] && [ -n "${rel_kernel:-}" ]; then
        cat << EOF >> "$GRUB_CFG"
        echo "Iniciando Debian Live via HTTP (Modo Ventoy)..."
        linux (http,\$pxe_server)/extracted/$rel_kernel boot=live components fetch=http://\$pxe_server/$http_dir/$rel_iso_url
        initrd (http,\$pxe_server)/extracted/$rel_initrd
EOF
    elif [ "$os_type" = "clonezilla" ] && [ -n "${rel_kernel:-}" ]; then
        cat << EOF >> "$GRUB_CFG"
        echo "Iniciando Clonezilla Live via HTTP (Modo Ventoy)..."
        linux (http,\$pxe_server)/extracted/$rel_kernel boot=live config noswap edd=on nomodeset locales=pt_BR.UTF-8 keyboard-layouts=br fetch=http://\$pxe_server/$http_dir/$rel_iso_url
        initrd (http,\$pxe_server)/extracted/$rel_initrd
EOF
    elif [ "$os_type" = "arch" ] && [ -n "${rel_kernel:-}" ]; then
        cat << EOF >> "$GRUB_CFG"
        echo "Iniciando Arch Linux via HTTP (Modo Ventoy)..."
        linux (http,\$pxe_server)/extracted/$rel_kernel archiso_http_srv=http://\$pxe_server/$http_dir/ ip=dhcp cms_verify=y
        initrd (http,\$pxe_server)/extracted/$rel_initrd
EOF
    elif [ "$os_type" = "windows" ]; then
        cat << EOF >> "$GRUB_CFG"
        echo "Iniciando Instalador Microsoft Windows (Modo Ventoy)..."
        if [ "\$grub_platform" = "pc" ]; then
            linux16 (http,\$pxe_server)/bios/undionly.kpxe
        else
            chainloader (http,\$pxe_server)/uefi/ipxe.efi
        fi
EOF
    else
        cat << EOF >> "$GRUB_CFG"
        echo "Iniciando $iso_name (Modo Ventoy)..."
        if [ -n "${rel_kernel:-}" ] && [ -n "${rel_initrd:-}" ]; then
            linux (http,\$pxe_server)/extracted/$rel_kernel ip=dhcp
            initrd (http,\$pxe_server)/extracted/$rel_initrd
        elif [ "\$grub_platform" = "pc" ]; then
            linux16 (http,\$pxe_server)/memdisk iso raw
            initrd16 (http,\$pxe_server)/$http_dir/$rel_iso_url
        else
            chainloader (http,\$pxe_server)/uefi/ipxe.efi
        fi
EOF
    fi

    cat << EOF >> "$GRUB_CFG"
    }

    menuentry "   [2] Iniciar via iPXE Sanboot (Emulação CD-ROM Virtual em Rede)" --class net {
        echo "Iniciando emulação de CD-ROM Virtual via iPXE Sanboot..."
        if [ "\$grub_platform" = "pc" ]; then
            linux16 (http,\$pxe_server)/bios/undionly.kpxe
        else
            chainloader (http,\$pxe_server)/uefi/ipxe.efi
        fi
    }

    menuentry "   [3] Iniciar em Modo Memdisk (Carregar ISO inteira na RAM)" --class ram {
        echo "Carregando $iso_name na memória RAM (Modo Memdisk estilo Ventoy)..."
        if [ "\$grub_platform" = "pc" ]; then
            linux16 (http,\$pxe_server)/memdisk iso raw
            initrd16 (http,\$pxe_server)/$http_dir/$rel_iso_url
        else
            echo "Memdisk requer BIOS Legacy. Inicializando via emulação iPXE em UEFI..."
            sleep 2
            chainloader (http,\$pxe_server)/uefi/ipxe.efi
        fi
    }

    menuentry "   << Voltar ao Menu Principal" --class cancel {
        configfile (tftp)/grub/grub.cfg
    }
}

EOF

    # --- Entrada no PXELINUX (BIOS Legacy) ---
    cat << EOF >> "$SYS_CFG"
LABEL iso_$ISO_COUNT
    MENU LABEL $ISO_COUNT. $os_title ($iso_size_str) [Normal]
EOF

    if [ "$os_type" = "ubuntu" ] && [ -n "${rel_kernel:-}" ]; then
        cat << EOF >> "$SYS_CFG"
    KERNEL http://$SERVER_IP/extracted/$rel_kernel
    INITRD http://$SERVER_IP/extracted/$rel_initrd
    APPEND ip=dhcp url=http://$SERVER_IP/$http_dir/$rel_iso_url ds=nocloud-net ---
EOF
    elif [ "$os_type" = "debian" ] && [ -n "${rel_kernel:-}" ]; then
        cat << EOF >> "$SYS_CFG"
    KERNEL http://$SERVER_IP/extracted/$rel_kernel
    INITRD http://$SERVER_IP/extracted/$rel_initrd
    APPEND boot=live components fetch=http://$SERVER_IP/$http_dir/$rel_iso_url
EOF
    elif [ "$os_type" = "proxmox" ] && [ -n "${rel_kernel:-}" ]; then
        cat << EOF >> "$SYS_CFG"
    KERNEL http://$SERVER_IP/extracted/$rel_kernel
    INITRD http://$SERVER_IP/extracted/$rel_initrd
    APPEND vga=791 splash=silent ip=dhcp proxmox-iso=http://$SERVER_IP/$http_dir/$rel_iso_url
EOF
    elif [ "$os_type" = "clonezilla" ] && [ -n "${rel_kernel:-}" ]; then
        cat << EOF >> "$SYS_CFG"
    KERNEL http://$SERVER_IP/extracted/$rel_kernel
    INITRD http://$SERVER_IP/extracted/$rel_initrd
    APPEND boot=live config noswap edd=on nomodeset locales=pt_BR.UTF-8 keyboard-layouts=br fetch=http://$SERVER_IP/$http_dir/$rel_iso_url
EOF
    elif [ "$os_type" = "arch" ] && [ -n "${rel_kernel:-}" ]; then
        cat << EOF >> "$SYS_CFG"
    KERNEL http://$SERVER_IP/extracted/$rel_kernel
    INITRD http://$SERVER_IP/extracted/$rel_initrd
    APPEND archiso_http_srv=http://$SERVER_IP/$http_dir/ ip=dhcp cms_verify=y
EOF
    elif [ "$os_type" = "windows" ]; then
        cat << EOF >> "$SYS_CFG"
    KERNEL /bios/undionly.kpxe
EOF
    else
        cat << EOF >> "$SYS_CFG"
    KERNEL memdisk
    INITRD http://$SERVER_IP/$http_dir/$rel_iso_url
    APPEND iso raw
EOF
    fi

    cat << EOF >> "$SYS_CFG"
LABEL iso_${ISO_COUNT}_mem
    MENU LABEL    -> [Memdisk RAM] $iso_name
    KERNEL memdisk
    INITRD http://$SERVER_IP/$http_dir/$rel_iso_url
    APPEND iso raw

EOF

    # --- Gera Entrada no iPXE com Opções de Boot estilo Ventoy ---
    echo "item iso_$ISO_COUNT $os_title ($iso_size_str) [$iso_source]" >> "$IPXE_CFG"

    cat << EOF >> "$IPXE_TARGETS"
:iso_$ISO_COUNT
menu Modos de Inicializacao Ventoy - $os_title ($iso_size_str)
item --gap --                --- Escolha o Modo de Boot (Estilo Ventoy) ---
item iso_${ISO_COUNT}_norm   [1] Iniciar em Modo Normal (HTTP Live Stream)
item iso_${ISO_COUNT}_san    [2] Iniciar via iPXE Sanboot (Virtual CD-ROM)
item iso_${ISO_COUNT}_mem    [3] Iniciar em Modo Memdisk (Carregar ISO na RAM)
item --gap --
item start                   << Voltar ao Menu Principal
choose --default iso_${ISO_COUNT}_norm --timeout 15000 target && goto \${target}

:iso_${ISO_COUNT}_san
echo [Ventoy] Conectando $iso_name como CD-ROM Virtual via HTTP Sanboot...
sanboot --no-describe http://$SERVER_IP/$http_dir/$rel_iso_url || goto failed

:iso_${ISO_COUNT}_mem
echo [Ventoy] Carregando $iso_name na memoria RAM (Memdisk)...
kernel http://$SERVER_IP/memdisk iso raw || goto failed
initrd http://$SERVER_IP/$http_dir/$rel_iso_url || goto failed
boot

:iso_${ISO_COUNT}_norm
EOF

    if [ "$os_type" = "ubuntu" ] && [ -n "${rel_kernel:-}" ]; then
        cat << EOF >> "$IPXE_TARGETS"
echo [Ventoy] Carregando Ubuntu Kernel e Initrd via HTTP...
kernel http://$SERVER_IP/extracted/$rel_kernel ip=dhcp url=http://$SERVER_IP/$http_dir/$rel_iso_url ds=nocloud-net --- || goto failed
initrd http://$SERVER_IP/extracted/$rel_initrd || goto failed
boot
EOF
    elif [ "$os_type" = "debian" ] && [ -n "${rel_kernel:-}" ]; then
        cat << EOF >> "$IPXE_TARGETS"
echo [Ventoy] Carregando Debian Live via HTTP...
kernel http://$SERVER_IP/extracted/$rel_kernel boot=live components fetch=http://$SERVER_IP/$http_dir/$rel_iso_url || goto failed
initrd http://$SERVER_IP/extracted/$rel_initrd || goto failed
boot
EOF
    elif [ "$os_type" = "proxmox" ] && [ -n "${rel_kernel:-}" ]; then
        cat << EOF >> "$IPXE_TARGETS"
echo [Ventoy] Carregando Proxmox VE Installer via HTTP...
kernel http://$SERVER_IP/extracted/$rel_kernel vga=791 splash=silent ip=dhcp proxmox-iso=http://$SERVER_IP/$http_dir/$rel_iso_url || goto failed
initrd http://$SERVER_IP/extracted/$rel_initrd || goto failed
boot
EOF
    elif [ "$os_type" = "clonezilla" ] && [ -n "${rel_kernel:-}" ]; then
        cat << EOF >> "$IPXE_TARGETS"
echo [Ventoy] Carregando Clonezilla Live via HTTP...
kernel http://$SERVER_IP/extracted/$rel_kernel boot=live config noswap edd=on nomodeset locales=pt_BR.UTF-8 keyboard-layouts=br fetch=http://$SERVER_IP/$http_dir/$rel_iso_url || goto failed
initrd http://$SERVER_IP/extracted/$rel_initrd || goto failed
boot
EOF
    elif [ "$os_type" = "arch" ] && [ -n "${rel_kernel:-}" ]; then
        cat << EOF >> "$IPXE_TARGETS"
echo [Ventoy] Carregando Arch Linux via HTTP...
kernel http://$SERVER_IP/extracted/$rel_kernel archiso_http_srv=http://$SERVER_IP/$http_dir/ ip=dhcp cms_verify=y || goto failed
initrd http://$SERVER_IP/extracted/$rel_initrd || goto failed
boot
EOF
    elif [ "$os_type" = "windows" ]; then
        cat << EOF >> "$IPXE_TARGETS"
echo [Ventoy] Inicializando Instalador Microsoft Windows via Sanboot HTTP...
sanboot --no-describe --drive 0x80 http://$SERVER_IP/$http_dir/$rel_iso_url || goto failed
EOF
    else
        cat << EOF >> "$IPXE_TARGETS"
echo [Ventoy] Inicializando $iso_name via Sanboot HTTP...
sanboot --no-describe http://$SERVER_IP/$http_dir/$rel_iso_url || goto iso_${ISO_COUNT}_mem
EOF
    fi

    echo "" >> "$IPXE_TARGETS"

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
    "icon": "$os_class",
    "source": "$iso_source",
    "http_url": "/$http_dir/$rel_iso_url"
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

# Rodapé do PXELINUX (BIOS Legacy)
cat << 'EOF' >> "$SYS_CFG"
LABEL -
    MENU LABEL  ------------------------------------------------
    MENU DISABLE

LABEL ipxe
    MENU LABEL >> Iniciar iPXE (HTTP Boot)
    KERNEL /bios/undionly.kpxe

LABEL reboot
    MENU LABEL >> Reiniciar Computador
    COM32 reboot.c32

LABEL poweroff
    MENU LABEL >> Desligar Computador
    COM32 poweroff.c32
EOF

# Espelha pxelinux.cfg para todos os caminhos procurados pelo Syslinux
cp "$SYS_CFG" "$TFTP_DIR/pxelinux.cfg/default" 2>/dev/null || true
cp "$SYS_CFG" "$TFTP_DIR/default" 2>/dev/null || true

# Espelha o grub.cfg para caminhos procurados por clientes UEFI, BIOS e TFTP
mkdir -p "$TFTP_DIR/grub/i386-pc" "$TFTP_DIR/grub/x86_64-efi" 2>/dev/null || true
cp "$GRUB_CFG" "$TFTP_DIR/grub/grub.cfg" 2>/dev/null || true
cp "$GRUB_CFG" "$TFTP_DIR/uefi/grub.cfg" 2>/dev/null || true
cp "$GRUB_CFG" "$TFTP_DIR/grub.cfg" 2>/dev/null || true
cp "$GRUB_CFG" "$TFTP_DIR/grub/i386-pc/grub.cfg" 2>/dev/null || true
cp "$GRUB_CFG" "$TFTP_DIR/grub/x86_64-efi/grub.cfg" 2>/dev/null || true

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

:failed
echo
echo [ERRO] Falha ao carregar a imagem via rede.
echo Pressione qualquer tecla para retornar ao menu principal...
prompt
goto start
EOF

# Anexa os blocos de boot das ISOs no iPXE
if [ -f "$IPXE_TARGETS" ]; then
    cat "$IPXE_TARGETS" >> "$IPXE_CFG"
    rm -f "$IPXE_TARGETS"
fi

# Espelha menu.ipxe para HTTP e TFTP
cp "$IPXE_CFG" "$TFTP_DIR/bios/menu.ipxe" 2>/dev/null || true
cp "$IPXE_CFG" "$TFTP_DIR/menu.ipxe" 2>/dev/null || true
cp "$IPXE_CFG" "/data/menu.ipxe" 2>/dev/null || true

# Permissões do TFTP
chmod -R 777 "$TFTP_DIR" 2>/dev/null || true
chown -R dnsmasq:dnsmasq "$TFTP_DIR" 2>/dev/null || chown -R nobody:nogroup "$TFTP_DIR" 2>/dev/null || true

echo "==> [PXE-SCAN] Concluído! $ISO_COUNT ISOs registradas em GRUB (UEFI), Syslinux (BIOS) e iPXE."
