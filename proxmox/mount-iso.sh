#!/usr/bin/env bash
# ==============================================================================
# ProxPXE - Assistente de Vinculação de Armazenamento de ISOs do Proxmox VE
# Executado no Shell do Host Proxmox VE (PVE)
# ==============================================================================

set -eo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m'

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[ERRO] Este script deve ser executado como root no nó Proxmox VE.${NC}"
    exit 1
fi

echo -e "\n${CYAN}==============================================================================${NC}"
echo -e "${WHITE}${BOLD}      PROXPXE - ASSISTENTE DE VINCULAÇÃO DE ISOS DO PROXMOX VE                ${NC}"
echo -e "${CYAN}==============================================================================${NC}"

# 1. Identifica o Container
CT_ID="${1:-}"
if [ -z "$CT_ID" ]; then
    echo -e "\n${YELLOW}Containers LXC disponíveis no nó:${NC}"
    pct list 2>/dev/null || true
    echo ""
    read -rp "Digite o ID do Container ProxPXE [Ex: 100]: " CT_ID
fi

if ! pct status "$CT_ID" >/dev/null 2>&1; then
    echo -e "${RED}[ERRO] Container LXC ID $CT_ID não encontrado!${NC}"
    exit 1
fi

# 2. Varre pastas de ISO disponíveis no Proxmox
echo -e "\n${BLUE}[1/4] Procurando pastas de ISOs nos storages do Proxmox...${NC}"

CANDIDATES=()
for d in /var/lib/vz/template/iso /mnt/pve/*/template/iso /mnt/*/template/iso /var/lib/pve/*/template/iso; do
    [ -d "$d" ] && CANDIDATES+=("$d")
done

if [ -f /etc/pve/storage.cfg ]; then
    while IFS= read -r st_path; do
        if [ -n "$st_path" ] && [ -d "$st_path/template/iso" ]; then
            CANDIDATES+=("$st_path/template/iso")
        fi
    done < <(grep -E '^[[:space:]]*path[[:space:]]+' /etc/pve/storage.cfg 2>/dev/null | awk '{print $2}')
fi

UNIQUE_DIRS=($(printf "%s\n" "${CANDIDATES[@]}" 2>/dev/null | sort -u))

if [ ${#UNIQUE_DIRS[@]} -eq 0 ]; then
    echo -e "${RED}[AVISO] Nenhuma pasta de ISO do Proxmox encontrada. Usando /var/lib/vz/template/iso por padrão.${NC}"
    mkdir -p /var/lib/vz/template/iso
    UNIQUE_DIRS=("/var/lib/vz/template/iso")
fi

echo -e "Pastas de ISO encontradas:"
idx=1
MENU_ITEMS=()
for dir in "${UNIQUE_DIRS[@]}"; do
    COUNT=$(find -L "$dir" -maxdepth 2 -type f \( -iname "*.iso" -o -iname "*.img" \) 2>/dev/null | wc -l)
    echo -e "  $idx) ${CYAN}$dir${NC} (${GREEN}$COUNT ISOs encontradas${NC})"
    MENU_ITEMS+=("$dir")
    idx=$((idx + 1))
done

CHOSEN_DIR=""
if [ ${#MENU_ITEMS[@]} -eq 1 ]; then
    CHOSEN_DIR="${MENU_ITEMS[0]}"
    echo -e "Selecionado automaticamente: ${GREEN}$CHOSEN_DIR${NC}"
else
    echo ""
    read -rp "Escolha o número da pasta desejada [1-${#MENU_ITEMS[@]}]: " opt
    opt=${opt:-1}
    CHOSEN_DIR="${MENU_ITEMS[$((opt - 1))]}"
fi

if [ -z "$CHOSEN_DIR" ] || [ ! -d "$CHOSEN_DIR" ]; then
    echo -e "${RED}[ERRO] Opção inválida.${NC}"
    exit 1
fi

# 3. Permissões e Montagem
echo -e "\n${BLUE}[2/4] Ajustando permissões de leitura no Proxmox host...${NC}"
chmod -R o+rX "$CHOSEN_DIR" 2>/dev/null || true
echo -e "${GREEN}[OK] Permissões aplicadas em $CHOSEN_DIR${NC}"

echo -e "\n${BLUE}[3/4] Vinculando ponto de montagem (mp0) no Container $CT_ID...${NC}"
pct set "$CT_ID" -mp0 "$CHOSEN_DIR,mp=/data/proxmox-iso"
echo -e "${GREEN}[OK] Configuração de mp0 salva no CT $CT_ID!${NC}"

# Reinicia o container para que o LXC monte o diretório
echo -e "\n${YELLOW}Reiniciando o Container $CT_ID para aplicar o ponto de montagem LXC...${NC}"
pct reboot "$CT_ID"

echo -e "Aguardando inicialização do container..."
for i in {1..30}; do
    if pct status "$CT_ID" 2>/dev/null | grep -q "status: running"; then
        break
    fi
    sleep 1
done
sleep 3

# 4. Executa scan e exibe resultado
echo -e "\n${BLUE}[4/4] Executando escaneamento e indexação das ISOs no ProxPXE...${NC}"
pct exec "$CT_ID" -- proxpxe scan

echo -e "\n${GREEN}==============================================================================${NC}"
echo -e "${GREEN}${BOLD}     ISOS DO PROXMOX VINCULADAS COM SUCESSO AO PROXPXE!                       ${NC}"
echo -e "${GREEN}==============================================================================${NC}"
echo -e "As ISOs de ${CYAN}$CHOSEN_DIR${NC} agora aparecem no Menu de Boot e no Painel Web!"
echo -e "${GREEN}==============================================================================${NC}\n"
