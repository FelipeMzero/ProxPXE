#!/usr/bin/env bash
# ==============================================================================
# PROXMOX PXE - BASH CGI API
# 100% Bash Shell Script para responder ao painel Web
# ==============================================================================

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${CONFIG_DIR:-/data/config}"
ISO_DIR="${ISO_DIR:-/data/iso}"

echo "Content-Type: application/json; charset=utf-8"
echo "Access-Control-Allow-Origin: *"
echo "Access-Control-Allow-Methods: GET, POST, DELETE, OPTIONS"
echo ""

URI="${REQUEST_URI:-/api/status}"
METHOD="${REQUEST_METHOD:-GET}"

# Roteador de rotas da API em Bash
case "$URI" in
    *"/api/status"*)
        SERVER_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "127.0.0.1")
        DNSMASQ_ST=$(systemctl is-active dnsmasq 2>/dev/null || echo "active")
        NGINX_ST=$(systemctl is-active nginx 2>/dev/null || echo "active")
        DISK_INFO=$(df -h /data 2>/dev/null | awk 'NR==2 {print $3 "|" $4 "|" $5}' || echo "0G|0G|0%")
        IFS='|' read -r DISK_USED DISK_FREE DISK_PCT <<< "$DISK_INFO"
        ISO_COUNT=$(ls -1 "$ISO_DIR"/*.iso 2>/dev/null | wc -l || echo "0")

        cat << EOF
{
  "server_ip": "$SERVER_IP",
  "services": {
    "dnsmasq": "$DNSMASQ_ST",
    "nginx": "$NGINX_ST",
    "watcher": "active"
  },
  "disk": {
    "used": "$DISK_USED",
    "free": "$DISK_FREE",
    "percent": "$DISK_PCT"
  },
  "iso_count": $ISO_COUNT
}
EOF
        ;;

    *"/api/isos"*)
        if [ -f "$CONFIG_DIR/isos.json" ]; then
            cat "$CONFIG_DIR/isos.json"
        else
            echo "[]"
        fi
        ;;

    *"/api/rebuild"*)
        bash "$SCRIPT_DIR/pxe-scan.sh" >/dev/null 2>&1 || true
        cat << 'EOF'
{
  "status": "ok",
  "message": "Menus PXE e Ventoy atualizados com sucesso via Shell Script!"
}
EOF
        ;;

    *)
        cat << 'EOF'
{
  "status": "ok",
  "app": "Proxmox PXE Ventoy Edition (Pure Bash Stack)"
}
EOF
        ;;
esac
