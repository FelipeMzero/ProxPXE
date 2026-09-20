#!/usr/bin/env bash
# ==============================================================================
# ProxPXE - Gerenciador de Download de ISOs via URL em Segundo Plano (100% Bash)
# ==============================================================================

set -eo pipefail

ISO_DIR="${ISO_DIR:-/data/iso}"
CONFIG_DIR="${CONFIG_DIR:-/data/config}"
STATUS_FILE="$CONFIG_DIR/download_status.json"
PID_FILE="/tmp/proxpxe_downloader.pid"
LOG_FILE="/tmp/proxpxe_downloader.log"

mkdir -p "$ISO_DIR" "$CONFIG_DIR"

start_download() {
    local url="$1"
    local custom_name="${2:-}"

    # Extrai ou define nome do arquivo
    local filename
    if [ -n "$custom_name" ]; then
        filename="$custom_name"
    else
        filename=$(basename "${url%%\?*}")
    fi

    # Garante extensão .iso
    if [[ "$filename" != *.iso && "$filename" != *.img ]]; then
        filename="${filename}.iso"
    fi

    local target_part="$ISO_DIR/${filename}.part"
    local target_final="$ISO_DIR/${filename}"

    # Grava status inicial
    cat << EOF > "$STATUS_FILE"
{
  "active": true,
  "url": "$url",
  "filename": "$filename",
  "downloaded_mb": 0,
  "total_mb": 0,
  "percent": 0,
  "speed": "Iniciando...",
  "status": "Conectando ao servidor..."
}
EOF

    # Inicia o download em segundo plano
    (
        rm -f "$LOG_FILE"
        # Executa wget com progresso detalhado
        wget -c "$url" -O "$target_part" 2> "$LOG_FILE" &
        WGET_PID=$!
        echo "$WGET_PID" > "$PID_FILE"

        # Loop de monitoramento de progresso
        while kill -0 "$WGET_PID" 2>/dev/null; do
            if [ -f "$target_part" ]; then
                cur_bytes=$(stat -c%s "$target_part" 2>/dev/null || stat -f%z "$target_part" 2>/dev/null || echo "0")
                cur_mb=$((cur_bytes / 1048576))

                # Extrai porcentagem e velocidade do log do wget se houver
                pct=$(grep -o '[0-9]\{1,3\}%' "$LOG_FILE" | tail -n1 | tr -d '%' || echo "0")
                speed=$(grep -o '[0-9.]\+ *[KMGT]B/s' "$LOG_FILE" | tail -n1 || echo "Baixando...")

                cat << EOF > "$STATUS_FILE"
{
  "active": true,
  "url": "$url",
  "filename": "$filename",
  "downloaded_mb": $cur_mb,
  "percent": ${pct:-0},
  "speed": "$speed",
  "status": "Baixando..."
}
EOF
            fi
            sleep 1.5
        done

        # Aguarda finalização do processo
        wait "$WGET_PID" 2>/dev/null
        exit_code=$?

        if [ $exit_code -eq 0 ] && [ -f "$target_part" ]; then
            mv "$target_part" "$target_final"
            total_mb=$(du -m "$target_final" | cut -f1)
            cat << EOF > "$STATUS_FILE"
{
  "active": false,
  "url": "$url",
  "filename": "$filename",
  "downloaded_mb": $total_mb,
  "percent": 100,
  "speed": "Concluído",
  "status": "Download concluído com sucesso!"
}
EOF
            # Regenera menu do ProxPXE
            SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
            bash "$SCRIPT_DIR/pxe-scan.sh" || true
        else
            cat << EOF > "$STATUS_FILE"
{
  "active": false,
  "url": "$url",
  "filename": "$filename",
  "percent": 0,
  "speed": "Falha",
  "status": "Erro no download ou cancelado"
}
EOF
        fi
        rm -f "$PID_FILE"
    ) >/dev/null 2>&1 &

    echo "Download iniciado em segundo plano"
}

cancel_download() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        kill -9 "$PID" 2>/dev/null || true
        rm -f "$PID_FILE"
    fi

    # Remove arquivos .part incompletos
    rm -f "$ISO_DIR"/*.part

    cat << 'EOF' > "$STATUS_FILE"
{
  "active": false,
  "status": "Download cancelado pelo usuário",
  "percent": 0
}
EOF
    echo "Download cancelado com sucesso"
}

status_download() {
    if [ -f "$STATUS_FILE" ]; then
        cat "$STATUS_FILE"
    else
        cat << 'EOF'
{
  "active": false,
  "status": "Nenhum download em andamento"
}
EOF
    fi
}

case "${1:-}" in
    start)
        start_download "$2" "${3:-}"
        ;;
    cancel)
        cancel_download
        ;;
    status)
        status_download
        ;;
esac
