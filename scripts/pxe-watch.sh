#!/usr/bin/env bash
# ==============================================================================
# PROXMOX PXE - DAEMON DE MONITORAMENTO AUTOMÁTICO DE PASTAS
# 100% Bash Shell Script
# ==============================================================================

set -eo pipefail

ISO_DIR="${ISO_DIR:-/data/iso}"
THEME_DIR="${THEME_DIR:-/data/theme}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$ISO_DIR" "$THEME_DIR"

echo "==> [PXE-WATCH] Iniciando monitor de eventos em $ISO_DIR e $THEME_DIR..."

# Executa detecção de rede, tema e escaneamento iniciais
bash "$SCRIPT_DIR/pxe-network.sh" apply || true
bash "$SCRIPT_DIR/pxe-theme.sh" || true
bash "$SCRIPT_DIR/pxe-scan.sh" || true

# Monitoramento com inotifywait se disponível
if command -v inotifywait >/dev/null 2>&1; then
    echo "    -> Usando monitoramento nativo por inotifywait."
    while true; do
        inotifywait -r -e create,delete,modify,moved_to "$ISO_DIR" "$THEME_DIR" 2>/dev/null || true
        echo "==> [PXE-WATCH] Alteração detectada! Atualizando menus..."
        sleep 2
        bash "$SCRIPT_DIR/pxe-theme.sh" || true
        bash "$SCRIPT_DIR/pxe-scan.sh" || true
    done
else
    # Fallback por verificação periódica de hash/modificação
    echo "    -> inotifywait não encontrado, utilizando verificação periódica (10s)."
    LAST_STATE=""
    while true; do
        CURRENT_STATE=$(ls -la "$ISO_DIR" "$THEME_DIR" 2>/dev/null | md5sum | awk '{print $1}')
        if [ "$CURRENT_STATE" != "$LAST_STATE" ]; then
            if [ -n "$LAST_STATE" ]; then
                echo "==> [PXE-WATCH] Mudança detectada! Atualizando menus..."
                bash "$SCRIPT_DIR/pxe-theme.sh" || true
                bash "$SCRIPT_DIR/pxe-scan.sh" || true
            fi
            LAST_STATE="$CURRENT_STATE"
        fi
        sleep 10
    done
fi
