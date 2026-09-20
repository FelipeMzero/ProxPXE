#!/usr/bin/env bash
# ==============================================================================
# ProxPXE - Analisador Detalhado de Armazenamento e Disco (100% Bash)
# ==============================================================================

set -eo pipefail

ISO_DIR="${ISO_DIR:-/data/iso}"
PVE_ISO_DIR="${PVE_ISO_DIR:-/data/proxmox-iso}"
EXTRACTED_DIR="${EXTRACTED_DIR:-/data/extracted}"

# Espaço geral do sistema de arquivos /data
TARGET_MOUNT="/data"
[ -d "$TARGET_MOUNT" ] || TARGET_MOUNT="$ISO_DIR"

DISK_RAW=$(df -m "$TARGET_MOUNT" 2>/dev/null | awk 'NR==2 {print $2 "|" $3 "|" $4 "|" $5}' || echo "102400|20480|81920|20%")
IFS='|' read -r TOTAL_MB USED_MB FREE_MB PCT_STR <<< "$DISK_RAW"
TOTAL_MB=${TOTAL_MB:-102400}
USED_MB=${USED_MB:-0}
FREE_MB=${FREE_MB:-102400}
PCT_STR=${PCT_STR:-"0%"}

# Espaço ocupado pelas ISOs (locais e Proxmox)
ISO_SIZE_MB=$(du -m "$ISO_DIR" "$PVE_ISO_DIR" 2>/dev/null | tail -n1 | cut -f1 || echo "0")

# Espaço ocupado por kernels extraídos
EXTRACTED_SIZE_MB=$(du -m "$EXTRACTED_DIR" 2>/dev/null | tail -n1 | cut -f1 || echo "0")

cat << EOF
{
  "total_gb": $(awk "BEGIN {printf \"%.2f\", $TOTAL_MB/1024}"),
  "used_gb": $(awk "BEGIN {printf \"%.2f\", $USED_MB/1024}"),
  "free_gb": $(awk "BEGIN {printf \"%.2f\", $FREE_MB/1024}"),
  "percent": "$PCT_STR",
  "iso_storage_mb": $ISO_SIZE_MB,
  "extracted_mb": $EXTRACTED_SIZE_MB,
  "iso_files": [
EOF

first=1
for file in "$ISO_DIR"/*.iso "$ISO_DIR"/*.img "$PVE_ISO_DIR"/*.iso "$PVE_ISO_DIR"/*.img; do
    [ -f "$file" ] || continue
    name=$(basename "$file")
    size_mb=$(du -m "$file" | cut -f1)
    if [ $first -eq 0 ]; then echo "," ; fi
    first=0
    cat << EOF
    {
      "name": "$name",
      "size_mb": $size_mb,
      "size_gb": $(awk "BEGIN {printf \"%.2f\", $size_mb/1024}")
    }
EOF
done

cat << 'EOF'
  ]
}
EOF
