#!/usr/bin/env bash
# ==============================================================================
# ProxPXE - Monitor de Usuários Conectados e Progresso de Instalação (100% Bash)
# ==============================================================================

set -eo pipefail

CONFIG_DIR="${CONFIG_DIR:-/data/config}"
CLIENTS_FILE="$CONFIG_DIR/clients_progress.json"
mkdir -p "$CONFIG_DIR"

# Registra ou atualiza status de um cliente
report_client() {
    local ip="$1"
    local mac="${2:-00:00:00:00:00:00}"
    local host="${3:-Computador}"
    local iso="${4:-ISO}"
    local pct="${5:-0}"
    local status="${6:-Em andamento}"
    local now
    now=$(date "+%H:%M:%S")

    # Atualiza registro em arquivo temporário
    local client_record="/tmp/client_${ip//./_}.info"
    cat << EOF > "$client_record"
{
  "ip": "$ip",
  "mac": "$mac",
  "hostname": "$host",
  "iso": "$iso",
  "percent": $pct,
  "status": "$status",
  "last_seen": "$now"
}
EOF
    build_json
}

# Constrói o JSON consolidado de clientes e conexões ativas
build_json() {
    echo "[" > "$CLIENTS_FILE"
    local first=1

    # 1. Clientes registrados por webhook/relato
    for rec in /tmp/client_*.info; do
        [ -f "$rec" ] || continue
        if [ $first -eq 0 ]; then echo "," >> "$CLIENTS_FILE"; fi
        first=0
        cat "$rec" >> "$CLIENTS_FILE"
    done

    # 2. Leases DHCP recentes do Dnsmasq
    if [ -f /var/lib/misc/dnsmasq.leases ]; then
        while read -r expiry mac ip host client_id; do
            # Se já não foi adicionado
            if [ ! -f "/tmp/client_${ip//./_}.info" ]; then
                if [ $first -eq 0 ]; then echo "," >> "$CLIENTS_FILE"; fi
                first=0
                cat << EOF >> "$CLIENTS_FILE"
{
  "ip": "$ip",
  "mac": "$mac",
  "hostname": "${host:-Cliente-PXE}",
  "iso": "Rede Local",
  "percent": 100,
  "status": "Conectado via DHCP",
  "last_seen": "Ativo"
}
EOF
            fi
        done < /var/lib/misc/dnsmasq.leases
    fi

    echo "]" >> "$CLIENTS_FILE"
    cat "$CLIENTS_FILE"
}

case "${1:-}" in
    report)
        report_client "$2" "${3:-}" "${4:-}" "${5:-}" "${6:-0}" "${7:-Instalando}"
        ;;
    list)
        build_json
        ;;
    *)
        build_json
        ;;
esac
