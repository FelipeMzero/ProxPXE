#!/usr/bin/env bash
# ==============================================================================
# Script de Instalação Interna do Servidor PXE Ventoy (100% Bash Shell Script)
# Executado dentro do Container LXC (Debian 12) no Proxmox VE
# ==============================================================================

set -eo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_step() { echo -e "\n${CYAN}==>${NC} ${YELLOW}$1${NC}"; }
log_ok() { echo -e "${GREEN}[OK]${NC} $1"; }

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[ERRO] Este script deve ser executado como root.${NC}"
    exit 1
fi

log_step "1/6: Atualizando repositórios e instalando dependências do sistema..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y \
    dnsmasq \
    nginx \
    fcgiwrap \
    grub-common \
    grub-pc-bin \
    grub-efi-amd64-bin \
    grub-efi-ia32-bin \
    ipxe \
    pxelinux \
    syslinux-common \
    xorriso \
    p7zip-full \
    inotify-tools \
    fonts-dejavu-core \
    unifont \
    curl \
    wget \
    rsync \
    net-tools

log_ok "Pacotes do sistema instalados com sucesso!"

log_step "2/6: Criando estrutura de pastas de dados e boot..."
mkdir -p /data/iso
mkdir -p /data/extracted
mkdir -p /data/theme/fonts
mkdir -p /data/theme/icons
mkdir -p /data/config
mkdir -p /var/lib/tftpboot/bios
mkdir -p /var/lib/tftpboot/uefi
mkdir -p /var/lib/tftpboot/grub/fonts
mkdir -p /var/lib/tftpboot/theme

chown -R www-data:www-data /data 2>/dev/null || true
chmod -R 775 /data
chmod -R 777 /data/iso /data/config /data/extracted 2>/dev/null || true
chmod -R 755 /var/lib/tftpboot

log_step "3/6: Compilando ambiente de Boot GRUB2 Netboot (UEFI & BIOS) e iPXE..."
grub-mknetdir --net-directory=/var/lib/tftpboot --subdir=/grub

if [ -f /var/lib/tftpboot/grub/x86_64-efi/core.efi ]; then
    cp /var/lib/tftpboot/grub/x86_64-efi/core.efi /var/lib/tftpboot/uefi/grubnetx64.efi
elif [ -f /usr/lib/grub/x86_64-efi-signed/grubnetx64.efi.signed ]; then
    cp /usr/lib/grub/x86_64-efi-signed/grubnetx64.efi.signed /var/lib/tftpboot/uefi/grubnetx64.efi
fi

# Syslinux / BIOS Legacy
if [ -f /usr/lib/PXELINUX/lpxelinux.0 ]; then
    cp /usr/lib/PXELINUX/lpxelinux.0 /var/lib/tftpboot/bios/lpxelinux.0
elif [ -f /usr/lib/PXELINUX/pxelinux.0 ]; then
    cp /usr/lib/PXELINUX/pxelinux.0 /var/lib/tftpboot/bios/lpxelinux.0
fi

for mod in ldlinux.c32 menu.c32 vesamenu.c32 libcom32.c32 libutil.c32 chain.c32; do
    find /usr/lib/syslinux -name "$mod" -exec cp {} /var/lib/tftpboot/bios/ \; 2>/dev/null || true
done

# iPXE & Memdisk
find /usr/lib/ipxe -name "ipxe.efi" -exec cp {} /var/lib/tftpboot/uefi/ipxe.efi \; 2>/dev/null || true
find /usr/lib/ipxe -name "undionly.kpxe" -exec cp {} /var/lib/tftpboot/bios/undionly.kpxe \; 2>/dev/null || true
find /usr/lib/syslinux -name "memdisk" -exec cp {} /var/lib/tftpboot/memdisk \; 2>/dev/null || true

log_ok "Binários de boot compilados com sucesso!"

log_step "4/6: Instalando scripts da aplicação PXE em /opt/pxe-server..."
TARGET_DIR="/opt/pxe-server"
mkdir -p "$TARGET_DIR/scripts" "$TARGET_DIR/web" "$TARGET_DIR/configs"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -d "$SCRIPT_DIR/scripts" ]; then
    cp -r "$SCRIPT_DIR/scripts" "$TARGET_DIR/"
    cp -r "$SCRIPT_DIR/web" "$TARGET_DIR/"
    cp -r "$SCRIPT_DIR/configs" "$TARGET_DIR/"
    cp -r "$SCRIPT_DIR/data/theme"/* /data/theme/ 2>/dev/null || true
fi

chmod +x "$TARGET_DIR"/scripts/*.sh
ln -sf "$TARGET_DIR/scripts/pxe-cli.sh" /usr/local/bin/proxpxe
ln -sf "$TARGET_DIR/scripts/pxe-cli.sh" /usr/local/bin/pxe-cli

# Copia theme.ini padrão para /data/config se não existir
if [ ! -f /data/config/theme.ini ] && [ -f "$TARGET_DIR/configs/theme.ini" ]; then
    cp "$TARGET_DIR/configs/theme.ini" /data/config/theme.ini
fi

# Gera tema inicial e converte fontes
bash "$TARGET_DIR/scripts/pxe-theme.sh"

log_step "5/6: Configurando Dnsmasq (ProxyDHCP Dinâmico) e Nginx..."

# Auto-detecta a rede onde o CT está conectado (estática ou DHCP) e gera dnsmasq.conf dinâmico
bash "$TARGET_DIR/scripts/pxe-network.sh" apply

# Nginx
cp "$TARGET_DIR/configs/nginx.conf" /etc/nginx/sites-available/pxe-server.conf
rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/pxe-server.conf /etc/nginx/sites-enabled/pxe-server.conf

log_step "6/6: Habilitando e iniciando serviços systemd..."
cp "$TARGET_DIR/configs/pxe-watcher.service" /etc/systemd/system/pxe-watcher.service
systemctl daemon-reload

# Garante permissões finais para o Nginx e fcgiwrap (upload e download de ISOs)
chown -R www-data:www-data /data 2>/dev/null || true
chmod -R 777 /data/iso /data/config /data/extracted 2>/dev/null || true

systemctl enable --now fcgiwrap
systemctl restart fcgiwrap
systemctl enable --now dnsmasq
systemctl restart dnsmasq
systemctl enable --now nginx
systemctl restart nginx
systemctl enable --now pxe-watcher
systemctl restart pxe-watcher

# Executa escaneamento inicial
bash "$TARGET_DIR/scripts/pxe-scan.sh"

log_ok "Serviços iniciados com sucesso!"

HOST_IP=$(ip -4 -o addr show eth0 2>/dev/null | awk '{print $4}' | cut -d/ -f1 | head -n1 || true)
if [ -z "$HOST_IP" ]; then
    HOST_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "127.0.0.1")
fi

echo -e "\n${GREEN}==============================================================================${NC}"
echo -e "${GREEN}      PROXMOX PXE VENTOY EDITION (BASH) INSTALADO COM SUCESSO!                ${NC}"
echo -e "${GREEN}==============================================================================${NC}"
echo -e "${CYAN}Painel de Gerenciamento Web:${NC} http://${HOST_IP}"
echo -e "${CYAN}Pasta para colocar ISOs:${NC}     /data/iso/"
echo -e "${CYAN}Pasta de Logo e Papel de Parede:${NC} /data/theme/"
echo -e "${CYAN}Pasta de Fontes (.pf2 / .ttf):${NC}  /data/theme/fonts/"
echo -e "${CYAN}Comando CLI de Manutenção:${NC}   pxe-cli (ex: pxe-cli scan, pxe-cli status)"
echo -e "${GREEN}==============================================================================${NC}\n"
