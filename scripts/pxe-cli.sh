#!/usr/bin/env bash
# ==============================================================================
# PROXMOX PXE - CLI INTERATIVA DE GERENCIAMENTO
# 100% Bash Shell Script
# ==============================================================================

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ISO_DIR="${ISO_DIR:-/data/iso}"
THEME_DIR="${THEME_DIR:-/data/theme}"
CONFIG_DIR="${CONFIG_DIR:-/data/config}"

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

case "${1:-}" in
    scan)
        echo -e "${CYAN}==> Escaneando ISOs e regenerando menus do PXE...${NC}"
        bash "$SCRIPT_DIR/pxe-scan.sh"
        ;;
    theme)
        echo -e "${CYAN}==> Atualizando tema Ventoy e fontes...${NC}"
        bash "$SCRIPT_DIR/pxe-theme.sh"
        ;;
    list)
        echo -e "${CYAN}==> Imagens ISO encontradas em $ISO_DIR:${NC}"
        if [ -f "$CONFIG_DIR/isos.json" ]; then
            cat "$CONFIG_DIR/isos.json"
        else
            ls -lh "$ISO_DIR"
        fi
        ;;
    status)
        echo -e "${CYAN}====================================================${NC}"
        echo -e "${GREEN}          STATUS DO SERVIDOR PROXPXE (PROXMOX)      ${NC}"
        echo -e "${CYAN}====================================================${NC}"
        echo -e "IP do Servidor: $(hostname -I | awk '{print $1}')"
        echo -e "Serviço Dnsmasq (ProxyDHCP/TFTP): $(systemctl is-active dnsmasq 2>/dev/null || echo 'desconhecido')"
        echo -e "Serviço Nginx (HTTP Streaming):   $(systemctl is-active nginx 2>/dev/null || echo 'desconhecido')"
        echo -e "Serviço Monitor de ISOs:          $(systemctl is-active pxe-watcher 2>/dev/null || echo 'desconhecido')"
        echo -e "Espaço em Disco (/data):          $(df -h /data 2>/dev/null | awk 'NR==2 {print $3 " usado / " $4 " livre (" $5 ")"}')"
        echo -e "ISOs cadastradas:                 $(ls -1 "$ISO_DIR"/*.iso 2>/dev/null | wc -l)"
        echo -e "${CYAN}====================================================${NC}"
        ;;
    mode)
        MODE="${2:-}"
        if [ "$MODE" = "proxy" ]; then
            echo -e "${YELLOW}Configurando Dnsmasq para modo ProxyDHCP (Seguro)...${NC}"
            SERVER_IP=$(hostname -I | awk '{print $1}')
            sed -i "s/^dhcp-range=.*/dhcp-range=$SERVER_IP,proxy,255.255.255.0/" /etc/dnsmasq.d/pxe.conf 2>/dev/null || true
            systemctl restart dnsmasq 2>/dev/null || true
            echo -e "${GREEN}Modo ProxyDHCP ativado com sucesso!${NC}"
        elif [ "$MODE" = "standalone" ]; then
            echo -e "${YELLOW}Configurando Dnsmasq para Servidor DHCP Completo...${NC}"
            systemctl restart dnsmasq 2>/dev/null || true
            echo -e "${GREEN}Modo Standalone DHCP ativado!${NC}"
        else
            echo "Uso: proxpxe mode [proxy|standalone]"
        fi
        ;;
    *)
        echo -e "${CYAN}ProxPXE Manager - Comandos disponíveis:${NC}"
        echo -e "  ${GREEN}proxpxe scan${NC}       - Escaneia a pasta /data/iso e regenera menus GRUB/iPXE"
        echo -e "  ${GREEN}proxpxe theme${NC}      - Atualiza layout, logo e converte fontes .ttf para .pf2"
        echo -e "  ${GREEN}proxpxe list${NC}       - Exibe as ISOs cadastradas"
        echo -e "  ${GREEN}proxpxe status${NC}     - Exibe status dos serviços e rede"
        echo -e "  ${GREEN}proxpxe mode proxy${NC} - Ativa modo ProxyDHCP (Não interfere no seu roteador)"
        ;;
esac
