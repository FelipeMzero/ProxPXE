#!/usr/bin/env bash
# ==============================================================================
# ProxPXE - API REST Completa em Bash CGI (100% Bash)
# ==============================================================================

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${CONFIG_DIR:-/data/config}"
ISO_DIR="${ISO_DIR:-/data/iso}"

echo "Content-Type: application/json; charset=utf-8"
echo "Access-Control-Allow-Origin: *"
echo "Access-Control-Allow-Methods: GET, POST, DELETE, OPTIONS"
echo "Access-Control-Allow-Headers: Content-Type, Authorization, X-Session-Token"
echo ""

URI="${REQUEST_URI:-/api/status}"
METHOD="${REQUEST_METHOD:-GET}"

# Lê corpo da requisição se for POST
POST_DATA=""
if [ "$METHOD" = "POST" ] && [ "${CONTENT_LENGTH:-0}" -gt 0 ]; then
    read -r -n "$CONTENT_LENGTH" POST_DATA || true
fi

# Roteador de endpoints
case "$URI" in
    *"/api/login"*)
        USER=$(echo "$POST_DATA" | grep -o '"username": *"[^"]*"' | cut -d'"' -f4 || echo "")
        PASS=$(echo "$POST_DATA" | grep -o '"password": *"[^"]*"' | cut -d'"' -f4 || echo "")
        TOKEN=$(bash "$SCRIPT_DIR/pxe-auth.sh" login "$USER" "$PASS" 2>/dev/null || true)
        
        if [ -n "$TOKEN" ]; then
            cat << EOF
{
  "status": "ok",
  "token": "$TOKEN",
  "username": "$USER"
}
EOF
        else
            cat << 'EOF'
{
  "status": "error",
  "message": "Usuário ou senha incorretos (Padrão: admin / admin)"
}
EOF
        fi
        ;;

    *"/api/change-password"*)
        USER=$(echo "$POST_DATA" | grep -o '"username": *"[^"]*"' | cut -d'"' -f4 || echo "admin")
        PASS=$(echo "$POST_DATA" | grep -o '"password": *"[^"]*"' | cut -d'"' -f4 || echo "")
        if [ -n "$PASS" ]; then
            bash "$SCRIPT_DIR/pxe-auth.sh" change "$USER" "$PASS" >/dev/null 2>&1
            cat << 'EOF'
{
  "status": "ok",
  "message": "Credenciais atualizadas com sucesso!"
}
EOF
        else
            cat << 'EOF'
{
  "status": "error",
  "message": "Senha não pode ser vazia"
}
EOF
        fi
        ;;

    *"/api/status"*)
        SERVER_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "127.0.0.1")
        DNSMASQ_ST=$(systemctl is-active dnsmasq 2>/dev/null || echo "active")
        NGINX_ST=$(systemctl is-active nginx 2>/dev/null || echo "active")
        WATCHER_ST=$(systemctl is-active pxe-watcher 2>/dev/null || echo "active")
        
        DISK_INFO=$(df -h /data 2>/dev/null | awk 'NR==2 {print $2 "|" $3 "|" $4 "|" $5}' || echo "0G|0G|0G|0%")
        IFS='|' read -r DISK_TOT DISK_USED DISK_FREE DISK_PCT <<< "$DISK_INFO"
        
        ISO_COUNT=$(ls -1 "$ISO_DIR"/*.iso 2>/dev/null | wc -l || echo "0")
        CLIENTS_COUNT=$(ls -1 /tmp/client_*.info 2>/dev/null | wc -l || echo "0")

        cat << EOF
{
  "app": "ProxPXE",
  "server_ip": "$SERVER_IP",
  "services": {
    "dnsmasq": "$DNSMASQ_ST",
    "nginx": "$NGINX_ST",
    "watcher": "$WATCHER_ST"
  },
  "disk": {
    "total": "$DISK_TOT",
    "used": "$DISK_USED",
    "free": "$DISK_FREE",
    "percent": "$DISK_PCT"
  },
  "iso_count": $ISO_COUNT,
  "clients_count": $CLIENTS_COUNT
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

    *"/api/disk-analysis"*)
        bash "$SCRIPT_DIR/pxe-disk.sh"
        ;;

    *"/api/connected-clients"*)
        bash "$SCRIPT_DIR/pxe-progress.sh" list
        ;;

    *"/api/download-iso"*)
        URL=$(echo "$POST_DATA" | grep -o '"url": *"[^"]*"' | cut -d'"' -f4 || echo "")
        NAME=$(echo "$POST_DATA" | grep -o '"filename": *"[^"]*"' | cut -d'"' -f4 || echo "")
        
        if [ -n "$URL" ]; then
            bash "$SCRIPT_DIR/pxe-downloader.sh" start "$URL" "$NAME" >/dev/null 2>&1 &
            cat << 'EOF'
{
  "status": "ok",
  "message": "Download da ISO iniciado em segundo plano!"
}
EOF
        else
            cat << 'EOF'
{
  "status": "error",
  "message": "URL da ISO é obrigatória"
}
EOF
        fi
        ;;

    *"/api/download-status"*)
        bash "$SCRIPT_DIR/pxe-downloader.sh" status
        ;;

    *"/api/cancel-download"*)
        bash "$SCRIPT_DIR/pxe-downloader.sh" cancel
        cat << 'EOF'
{
  "status": "ok",
  "message": "Download cancelado com sucesso."
}
EOF
        ;;

    *"/api/progress"*)
        # Endpoint para relatar progresso de instalação de um PC
        IP=$(echo "$QUERY_STRING" | grep -o 'ip=[^&]*' | cut -d'=' -f2 || echo "$REMOTE_ADDR")
        MAC=$(echo "$QUERY_STRING" | grep -o 'mac=[^&]*' | cut -d'=' -f2 || echo "00:00:00:00:00:00")
        HOST=$(echo "$QUERY_STRING" | grep -o 'host=[^&]*' | cut -d'=' -f2 || echo "PC-Cliente")
        ISO=$(echo "$QUERY_STRING" | grep -o 'iso=[^&]*' | cut -d'=' -f2 || echo "Instalador")
        PCT=$(echo "$QUERY_STRING" | grep -o 'percent=[^&]*' | cut -d'=' -f2 || echo "0")
        STATUS=$(echo "$QUERY_STRING" | grep -o 'status=[^&]*' | cut -d'=' -f2 || echo "Instalando")
        
        bash "$SCRIPT_DIR/pxe-progress.sh" report "$IP" "$MAC" "$HOST" "$ISO" "$PCT" "$STATUS" >/dev/null 2>&1
        cat << 'EOF'
{
  "status": "ok"
}
EOF
        ;;

    *"/api/delete-iso"*)
        FILENAME=$(echo "$POST_DATA" | grep -o '"filename": *"[^"]*"' | cut -d'"' -f4 || echo "")
        if [ -n "$FILENAME" ] && [ -f "$ISO_DIR/$FILENAME" ]; then
            rm -f "$ISO_DIR/$FILENAME"
            rm -rf "$EXTRACTED_DIR/${FILENAME%.*}"
            bash "$SCRIPT_DIR/pxe-scan.sh" >/dev/null 2>&1 || true
            cat << 'EOF'
{
  "status": "ok",
  "message": "ISO removida com sucesso!"
}
EOF
        else
            cat << 'EOF'
{
  "status": "error",
  "message": "Arquivo não encontrado"
}
EOF
        fi
        ;;

    *"/api/rebuild"*)
        bash "$SCRIPT_DIR/pxe-theme.sh" >/dev/null 2>&1 || true
        bash "$SCRIPT_DIR/pxe-scan.sh" >/dev/null 2>&1 || true
        cat << 'EOF'
{
  "status": "ok",
  "message": "Menus do ProxPXE atualizados com sucesso!"
}
EOF
        ;;

    *)
        cat << 'EOF'
{
  "app": "ProxPXE",
  "version": "1.0.0",
  "mode": "Pure Bash Stack"
}
EOF
        ;;
esac
