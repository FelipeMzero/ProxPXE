#!/usr/bin/env bash
# ==============================================================================
# ProxPXE - Script de Criação do Container LXC (CT) no Proxmox VE
# Execute no shell do nó Proxmox VE:
# bash -c "$(curl -fsSL https://raw.githubusercontent.com/FelipeMzero/ProxPXE/main/proxmox/create-ct.sh)"
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

if ! command -v pveversion >/dev/null 2>&1; then
    echo -e "${RED}[ERRO] Este script deve ser executado no shell do nó Proxmox VE (PVE).${NC}"
    exit 1
fi

clear
echo -e "${MAGENTA}==============================================================================${NC}"
echo -e "${CYAN}             PROXPXE - INSTALADOR AUTOMATIZADO NO PROXMOX VE                  ${NC}"
echo -e "${MAGENTA}==============================================================================${NC}"
echo -e "Este assistente criará um Container LXC otimizado para o ProxPXE"
echo -e "com Menu Gráfico estilo Ventoy, ProxyDHCP e Painel de Controle Web.\n"

# 1. CT ID
DEFAULT_CTID=$(pvesh get /cluster/nextid 2>/dev/null || echo "110")
read -r -p "Digite o ID para o Container [Padrão: $DEFAULT_CTID]: " CT_ID
CT_ID=${CT_ID:-$DEFAULT_CTID}

if pct status "$CT_ID" >/dev/null 2>&1; then
    echo -e "${RED}[ERRO] O Container ID $CT_ID já existe! Escolha outro ID.${NC}"
    exit 1
fi

# 2. Hostname
DEFAULT_HOSTNAME="proxpxe"
read -r -p "Nome da máquina (Hostname) [Padrão: $DEFAULT_HOSTNAME]: " CT_HOSTNAME
CT_HOSTNAME=${CT_HOSTNAME:-$DEFAULT_HOSTNAME}

# 3. Storage
AVAILABLE_STORAGES=$(pvesm status -content rootdir 2>/dev/null | awk 'NR>1 {print $1}')
DEFAULT_STORAGE=$(echo "$AVAILABLE_STORAGES" | head -n1)
echo -e "\nStorages disponíveis: ${CYAN}$AVAILABLE_STORAGES${NC}"
read -r -p "Escolha o Storage [Padrão: $DEFAULT_STORAGE]: " CT_STORAGE
CT_STORAGE=${CT_STORAGE:-$DEFAULT_STORAGE}

# 4. Tamanho do Disco
read -r -p "Tamanho do disco em GB [Padrão: 32]: " CT_DISK
CT_DISK=${CT_DISK:-32}

# 5. Memória RAM e Cores
read -r -p "Memória RAM em MB [Padrão: 2048]: " CT_RAM
CT_RAM=${CT_RAM:-2048}

read -r -p "Quantidade de Cores de CPU [Padrão: 2]: " CT_CORES
CT_CORES=${CT_CORES:-2}

# 6. Rede
DEFAULT_BRIDGE="vmbr0"
read -r -p "Bridge de Rede [Padrão: $DEFAULT_BRIDGE]: " CT_BRIDGE
CT_BRIDGE=${CT_BRIDGE:-$DEFAULT_BRIDGE}

echo -e "\nConfiguração de Endereço IP:"
echo -e "  1) DHCP (Automático pelo seu roteador - Recomendado)"
echo -e "  2) IP Estático (Fixo)"
read -r -p "Selecione a opção [1 ou 2, Padrão: 1]: " NET_CHOICE
NET_CHOICE=${NET_CHOICE:-1}

if [ "$NET_CHOICE" -eq 2 ]; then
    read -r -p "Informe o IP estático com máscara (Ex: 192.168.1.50/24): " STATIC_IP
    read -r -p "Informe o Gateway (Ex: 192.168.1.1): " STATIC_GW
    NET_CONFIG="name=eth0,bridge=${CT_BRIDGE},ip=${STATIC_IP},gw=${STATIC_GW}"
else
    NET_CONFIG="name=eth0,bridge=${CT_BRIDGE},ip=dhcp"
fi

# 7. Mapeamento das ISOs já existentes do Proxmox
PVE_ISO_DIR="/var/lib/vz/template/iso"
BIND_ISO=0
if [ -d "$PVE_ISO_DIR" ]; then
    echo -e "\n${YELLOW}[RECURSO ESPECIAL]${NC} A pasta de ISOs nativa do Proxmox (${PVE_ISO_DIR}) foi encontrada!"
    read -r -p "Deseja compartilhar as ISOs já baixadas no Proxmox diretamente com o ProxPXE? [S/n]: " SHARE_ISO
    SHARE_ISO=${SHARE_ISO:-S}
    if [[ "$SHARE_ISO" =~ ^[Ss]$ ]]; then
        BIND_ISO=1
    fi
fi

# 8. Download do Template Debian 12
echo -e "\n${BLUE}[1/5] Verificando template Debian 12 padrão...${NC}"
pveam update >/dev/null 2>&1 || true

TEMPLATE_STORAGE=$(pvesm status -content vztmpl 2>/dev/null | awk 'NR>1 {print $1}' | head -n1)
TEMPLATE_STORAGE=${TEMPLATE_STORAGE:-$CT_STORAGE}

DEBIAN_TEMPLATE=$(pveam available --section system 2>/dev/null | grep "debian-12-standard" | awk '{print $2}' | sort -V | tail -n1)

if [ -z "$DEBIAN_TEMPLATE" ]; then
    echo -e "${RED}[ERRO] Não foi possível encontrar o template Debian 12.${NC}"
    exit 1
fi

LOCAL_TEMPLATE_PATH="/var/lib/vz/template/cache/${DEBIAN_TEMPLATE}"
if [ ! -f "$LOCAL_TEMPLATE_PATH" ]; then
    echo -e "${CYAN}Baixando template: ${DEBIAN_TEMPLATE}...${NC}"
    pveam download "$TEMPLATE_STORAGE" "$DEBIAN_TEMPLATE"
fi

# 9. Criação do Container LXC
echo -e "\n${BLUE}[2/5] Criando Container LXC (CT $CT_ID)...${NC}"
pct create "$CT_ID" "${TEMPLATE_STORAGE}:vztmpl/${DEBIAN_TEMPLATE}" \
    -ostype debian \
    -hostname "$CT_HOSTNAME" \
    -cores "$CT_CORES" \
    -memory "$CT_RAM" \
    -swap 512 \
    -net0 "$NET_CONFIG" \
    -storage "$CT_STORAGE" \
    -rootfs "${CT_STORAGE}:${CT_DISK}" \
    -features nesting=1 \
    -onboot 1 \
    -unprivileged 0

if [ "$BIND_ISO" -eq 1 ]; then
    echo -e "${GREEN}Montando pasta de ISOs do Proxmox em /data/iso do container...${NC}"
    pct set "$CT_ID" -mp0 "${PVE_ISO_DIR},mp=/data/iso"
fi

# 10. Iniciar Container
echo -e "\n${BLUE}[3/5] Iniciando Container LXC...${NC}"
pct start "$CT_ID"

echo -e "Aguardando conexão de rede do container..."
for i in {1..30}; do
    if pct exec "$CT_ID" -- ping -c 1 1.1.1.1 >/dev/null 2>&1; then
        echo -e "${GREEN}Rede operacional!${NC}"
        break
    fi
    sleep 1
done

# 11. Instalação da Aplicação ProxPXE
echo -e "\n${BLUE}[4/5] Baixando repositório e instalando componentes do ProxPXE...${NC}"
pct exec "$CT_ID" -- apt-get update -y
pct exec "$CT_ID" -- apt-get install -y git curl

# Baixa o repositório oficial do ProxPXE
pct exec "$CT_ID" -- rm -rf /tmp/pxe-setup
pct exec "$CT_ID" -- git clone https://github.com/FelipeMzero/ProxPXE.git /tmp/pxe-setup
pct exec "$CT_ID" -- bash /tmp/pxe-setup/install.sh

# Obtém o IP final
CT_FINAL_IP=$(pct exec "$CT_ID" -- hostname -I | awk '{print $1}')

clear
echo -e "${GREEN}==============================================================================${NC}"
echo -e "${GREEN}            PARABÉNS! PROXPXE INSTALADO COM SUCESSO NO PROXMOX VE!            ${NC}"
echo -e "${GREEN}==============================================================================${NC}"
echo -e "  Container ID:             ${CYAN}${CT_ID} (${CT_HOSTNAME})${NC}"
echo -e "  Painel de Controle Web:   ${GREEN}http://${CT_FINAL_IP}${NC}"
echo -e "  Modo DHCP:                ${YELLOW}ProxyDHCP (Porta 4011)${NC} - Seguro para sua rede local!"
echo -e "  Pasta de ISOs:            ${CYAN}/data/iso/${NC}"
echo -e "  Pasta de Logo e Fundo:    ${CYAN}/data/theme/${NC}"
echo -e "  Pasta de Fontes:          ${CYAN}/data/theme/fonts/${NC}"
echo -e "------------------------------------------------------------------------------"
echo -e "  ${YELLOW}PRÓXIMOS PASSOS:${NC}"
echo -e "  1. Acesse o painel web no navegador: ${GREEN}http://${CT_FINAL_IP}${NC}"
echo -e "  2. Coloque arquivos .iso em /data/iso/ (ou acesse as ISOs já mapeadas do Proxmox)"
echo -e "  3. Ligue qualquer computador na rede e aperte ${CYAN}F12${NC} para boot via rede PXE!"
echo -e "${GREEN}==============================================================================${NC}\n"
