#!/usr/bin/env bash
# ==============================================================================
# ProxPXE - Script de Instalação e Montagem do Container LXC (CT) no Proxmox VE
# Execute no shell do nó Proxmox VE (PVE):
# bash -c "$(curl -fsSL https://raw.githubusercontent.com/FelipeMzero/ProxPXE/main/proxmox/create-ct.sh)"
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

if ! command -v pveversion >/dev/null 2>&1; then
    echo -e "${RED}[ERRO] Este script deve ser executado diretamente no nó do Proxmox VE.${NC}"
    exit 1
fi

clear
echo -e "${MAGENTA}==============================================================================${NC}"
echo -e "${CYAN}${BOLD}       PROXPXE - ASSISTENTE DE CRIAÇÃO DO CONTAINER NO PROXMOX VE             ${NC}"
echo -e "${MAGENTA}==============================================================================${NC}"
echo -e "Configuração guiada do Container LXC com suporte a boot PXE Ventoy e Painel Web.\n"

# 1. CT ID
DEFAULT_CTID=$(pvesh get /cluster/nextid 2>/dev/null || echo "110")
read -r -p "1. Digite o ID do Container LXC [Padrão: $DEFAULT_CTID]: " CT_ID
CT_ID=${CT_ID:-$DEFAULT_CTID}

if pct status "$CT_ID" >/dev/null 2>&1; then
    echo -e "${RED}[ERRO] O Container ID $CT_ID já existe! Escolha outro ID.${NC}"
    exit 1
fi

# 2. Hostname
DEFAULT_HOSTNAME="proxpxe"
read -r -p "2. Digite o nome da máquina (Hostname) [Padrão: $DEFAULT_HOSTNAME]: " CT_HOSTNAME
CT_HOSTNAME=${CT_HOSTNAME:-$DEFAULT_HOSTNAME}

# 3. Onde vai ser instalado o CT (Storage do Disco)
echo -e "\n${BOLD}3. Onde o Container será instalado (Escolha o Storage do Disco)?${NC}"

# Detecta storages disponíveis para rootfs
STORAGES=()
while IFS= read -r line; do
    [ -n "$line" ] && STORAGES+=("$line")
done < <(pvesm status -content rootdir 2>/dev/null | awk 'NR>1 {print $1}')

# Fallback se array vazio
if [ ${#STORAGES[@]} -eq 0 ]; then
    STORAGES=("local-lvm" "local-zfs" "local")
fi

echo -e "   Selecione o número correspondente ao storage do Proxmox:"
for i in "${!STORAGES[@]}"; do
    num=$((i + 1))
    storage_name="${STORAGES[$i]}"
    storage_info=$(pvesm status -storage "$storage_name" 2>/dev/null | awk 'NR>1 {print $2 ", Livre: " int($6/1024/1024) " GB"}' || true)
    if [ -n "$storage_info" ]; then
        echo -e "     ${CYAN}${num})${NC} ${BOLD}${storage_name}${NC} (${storage_info})"
    else
        echo -e "     ${CYAN}${num})${NC} ${BOLD}${storage_name}${NC}"
    fi
done

read -r -p "   Digite apenas o NÚMERO da opção desejada [1-${#STORAGES[@]}, Padrão: 1]: " STORAGE_CHOICE
STORAGE_CHOICE=${STORAGE_CHOICE:-1}

# Valida o número digitado
if [[ "$STORAGE_CHOICE" =~ ^[0-9]+$ ]] && [ "$STORAGE_CHOICE" -ge 1 ] && [ "$STORAGE_CHOICE" -le "${#STORAGES[@]}" ]; then
    INDEX=$((STORAGE_CHOICE - 1))
    CT_STORAGE="${STORAGES[$INDEX]}"
else
    echo -e "   ${YELLOW}[AVISO] Opção inválida. Usando a opção 1: ${STORAGES[0]}${NC}"
    CT_STORAGE="${STORAGES[0]}"
fi
echo -e "   -> Storage selecionado: ${GREEN}${BOLD}${CT_STORAGE}${NC}"

# 4. Quantidade de Armazenamento (Disco)
echo -e "\n${BOLD}4. Quantidade de Armazenamento (Tamanho do Disco do CT):${NC}"
read -r -p "   Informe o tamanho do disco em GB [Padrão: 32]: " CT_DISK
CT_DISK=${CT_DISK:-32}

# 5. Quantidade de Memória RAM
echo -e "\n${BOLD}5. Quantidade de Memória RAM:${NC}"
read -r -p "   Informe a memória RAM em MB [Padrão: 2048]: " CT_RAM
CT_RAM=${CT_RAM:-2048}

# 6. Quantidade de Memória SWAP
echo -e "\n${BOLD}6. Quantidade de Memória SWAP:${NC}"
read -r -p "   Informe a quantidade de SWAP em MB [Padrão: 512]: " CT_SWAP
CT_SWAP=${CT_SWAP:-512}

# Cores de CPU
CT_CORES=2

# 7. Configuração de Rede e Endereço IP
echo -e "\n${BOLD}7. Configuração de Rede e Endereço IP:${NC}"
DEFAULT_BRIDGE="vmbr0"
read -r -p "   Bridge de rede [Padrão: $DEFAULT_BRIDGE]: " CT_BRIDGE
CT_BRIDGE=${CT_BRIDGE:-$DEFAULT_BRIDGE}

echo -e "\n   Como deseja configurar o endereço IP do ProxPXE?"
echo -e "     ${CYAN}1) Usar a range da rede para pegar o IP automaticamente via DHCP (Recomendado)${NC}"
echo -e "     ${CYAN}2) Deixar um IP específico / fixo manualmente${NC}"
read -r -p "   Selecione a opção [1 ou 2, Padrão: 1]: " NET_CHOICE
NET_CHOICE=${NET_CHOICE:-1}

if [ "$NET_CHOICE" -eq 2 ]; then
    echo -e "\n   ${YELLOW}Configuração de IP Fixo / Específico:${NC}"
    read -r -p "   -> Informe o IP específico com a máscara CIDR (Ex: 192.168.1.50/24): " STATIC_IP
    read -r -p "   -> Informe o Gateway padrão da rede (Ex: 192.168.1.1): " STATIC_GW
    read -r -p "   -> Informe o Servidor DNS [Padrão: 1.1.1.1]: " STATIC_DNS
    STATIC_DNS=${STATIC_DNS:-1.1.1.1}
    NET_CONFIG="name=eth0,bridge=${CT_BRIDGE},ip=${STATIC_IP},gw=${STATIC_GW}"
else
    NET_CONFIG="name=eth0,bridge=${CT_BRIDGE},ip=dhcp"
fi

# 8. Mapeamento das ISOs já existentes do Proxmox
PVE_ISO_DIR="/var/lib/vz/template/iso"
BIND_ISO=0
if [ -d "$PVE_ISO_DIR" ]; then
    echo -e "\n${BOLD}8. Compartilhamento de ISOs existentes do Proxmox:${NC}"
    echo -e "   A pasta de ISOs nativa do Proxmox (${CYAN}${PVE_ISO_DIR}${NC}) foi encontrada!"
    echo -e "     ${CYAN}1) Sim (Recomendado - Economiza espaço e usa as ISOs já baixadas no Proxmox)${NC}"
    echo -e "     ${CYAN}2) Não (Pasta de ISOs separada e isolada)${NC}"
    read -r -p "   Selecione a opção [1 ou 2, Padrão: 1]: " SHARE_CHOICE
    SHARE_CHOICE=${SHARE_CHOICE:-1}
    if [ "$SHARE_CHOICE" = "1" ] || [[ "$SHARE_CHOICE" =~ ^[Ss]$ ]]; then
        BIND_ISO=1
        echo -e "   -> As ISOs do Proxmox serão compartilhadas com o ProxPXE!"
    fi
fi

# 9. Download do Template Debian 12
echo -e "\n${BLUE}[1/5] Atualizando catálogo e verificando template Debian 12...${NC}"
pveam update >/dev/null 2>&1 || true

TEMPLATE_STORAGE=$(pvesm status -content vztmpl 2>/dev/null | awk 'NR>1 {print $1}' | head -n1)
TEMPLATE_STORAGE=${TEMPLATE_STORAGE:-$CT_STORAGE}

DEBIAN_TEMPLATE=$(pveam available --section system 2>/dev/null | grep "debian-12-standard" | awk '{print $2}' | sort -V | tail -n1)

if [ -z "$DEBIAN_TEMPLATE" ]; then
    echo -e "${RED}[ERRO] Template Debian 12 não encontrado na lista oficial do Proxmox.${NC}"
    exit 1
fi

LOCAL_TEMPLATE_PATH="/var/lib/vz/template/cache/${DEBIAN_TEMPLATE}"
if [ ! -f "$LOCAL_TEMPLATE_PATH" ]; then
    echo -e "${CYAN}Baixando template oficial: ${DEBIAN_TEMPLATE}...${NC}"
    pveam download "$TEMPLATE_STORAGE" "$DEBIAN_TEMPLATE"
fi

# 10. Criação do Container LXC
echo -e "\n${BLUE}[2/5] Criando Container LXC (CT $CT_ID) no storage $CT_STORAGE...${NC}"
pct create "$CT_ID" "${TEMPLATE_STORAGE}:vztmpl/${DEBIAN_TEMPLATE}" \
    -ostype debian \
    -hostname "$CT_HOSTNAME" \
    -cores "$CT_CORES" \
    -memory "$CT_RAM" \
    -swap "$CT_SWAP" \
    -net0 "$NET_CONFIG" \
    -storage "$CT_STORAGE" \
    -rootfs "${CT_STORAGE}:${CT_DISK}" \
    -features nesting=1 \
    -onboot 1 \
    -unprivileged 0

if [ "$NET_CHOICE" -eq 2 ] && [ -n "${STATIC_DNS:-}" ]; then
    pct set "$CT_ID" -nameserver "$STATIC_DNS"
fi

if [ "$BIND_ISO" -eq 1 ]; then
    echo -e "${GREEN}Montando pasta de ISOs nativas do Proxmox em /data/iso do container...${NC}"
    pct set "$CT_ID" -mp0 "${PVE_ISO_DIR},mp=/data/iso"
fi

# 11. Iniciar Container
echo -e "\n${BLUE}[3/5] Inicializando Container LXC...${NC}"
pct start "$CT_ID"

echo -e "Aguardando conectividade de rede do container..."
for i in {1..30}; do
    if pct exec "$CT_ID" -- ping -c 1 1.1.1.1 >/dev/null 2>&1; then
        echo -e "${GREEN}Rede conectada com sucesso!${NC}"
        break
    fi
    sleep 1
done

# 12. Instalação do ProxPXE
echo -e "\n${BLUE}[4/5] Clonando e instalando ProxPXE dentro do Container...${NC}"
pct exec "$CT_ID" -- apt-get update -y
pct exec "$CT_ID" -- apt-get install -y git curl

pct exec "$CT_ID" -- rm -rf /tmp/pxe-setup
pct exec "$CT_ID" -- git clone https://github.com/FelipeMzero/ProxPXE.git /tmp/pxe-setup
pct exec "$CT_ID" -- bash /tmp/pxe-setup/install.sh

# Obtém IP final
CT_FINAL_IP=$(pct exec "$CT_ID" -- hostname -I | awk '{print $1}')

clear
echo -e "${GREEN}==============================================================================${NC}"
echo -e "${GREEN}${BOLD}           PARABÉNS! PROXPXE INSTALADO COM SUCESSO NO PROXMOX VE!             ${NC}"
echo -e "${GREEN}==============================================================================${NC}"
echo -e "  Container ID:             ${CYAN}${CT_ID} (${CT_HOSTNAME})${NC}"
echo -e "  Storage Utilizado:        ${CYAN}${CT_STORAGE} (${CT_DISK} GB)${NC}"
echo -e "  Memória RAM / SWAP:       ${CYAN}${CT_RAM} MB RAM / ${CT_SWAP} MB SWAP${NC}"
echo -e "  Endereço IP do ProxPXE:   ${GREEN}http://${CT_FINAL_IP}${NC}"
echo -e "  Modo DHCP:                ${YELLOW}ProxyDHCP (Porta 4011)${NC} - Não afeta seu roteador!"
echo -e "  Credenciais do Painel:    Usuário: ${BOLD}admin${NC} | Senha: ${BOLD}admin${NC}"
echo -e "------------------------------------------------------------------------------"
echo -e "  ${YELLOW}${BOLD}RECURSOS DO PAINEL WEB:${NC}"
echo -e "  1. Acesse no navegador: ${GREEN}http://${CT_FINAL_IP}${NC}"
echo -e "  2. Faça login com ${BOLD}admin / admin${NC}"
echo -e "  3. Descarregue ISOs diretamente via URL ou envie pelo computador"
echo -e "  4. Acompanhe a porcentagem (%) de instalação dos PCs conectados em tempo real"
echo -e "  5. Ligue qualquer máquina na rede e tecle ${CYAN}F12${NC} para boot PXE com tema Ventoy!"
echo -e "${GREEN}==============================================================================${NC}\n"
