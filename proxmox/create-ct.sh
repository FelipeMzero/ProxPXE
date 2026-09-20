#!/usr/bin/env bash
# ==============================================================================
# ProxPXE - Assistente Interativo de Instalação no Proxmox VE (Menu com Setas)
# Identidade Visual: Hospital Regional Menino Jesus
# Execute no shell do Proxmox VE:
# bash -c "$(curl -fsSL https://raw.githubusercontent.com/FelipeMzero/ProxPXE/main/proxmox/create-ct.sh)"
# ==============================================================================

set -eo pipefail

# Cores do terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m'

# Verifica se está rodando no Proxmox VE
if ! command -v pveversion >/dev/null 2>&1; then
    echo -e "${RED}[ERRO] Este assistente deve ser executado diretamente no nó do Proxmox VE (PVE).${NC}"
    exit 1
fi

CURRENT_NODE=$(hostname)
TITLE="ProxPXE - Hospital Regional Menino Jesus"

# Garante que o whiptail está instalado (padrão em Debian/Proxmox)
if ! command -v whiptail >/dev/null 2>&1; then
    apt-get update -y && apt-get install -y whiptail
fi

# ==============================================================================
# 1. TELA INICIAL DE BOAS-VINDAS
# ==============================================================================
whiptail --title "$TITLE" --msgbox "Bem-vindo ao instalador oficial do ProxPXE!\n\nEste assistente guiará a criação do Container LXC com menu interativo.\nUse as SETAS (↑ ↓) do teclado para navegar, TAB para alternar e ENTER para selecionar." 13 70

# ==============================================================================
# 2. SUPORTE A CLUSTER (SE FOR CLUSTER, ESCOLHER O NÓ ONDE INSTALAR)
# ==============================================================================
TARGET_NODE="$CURRENT_NODE"
if pvecm status >/dev/null 2>&1; then
    # Detecta nós do cluster
    NODE_LIST=()
    while IFS= read -r node; do
        [ -n "$node" ] || continue
        status="Online"
        if [ "$node" = "$CURRENT_NODE" ]; then
            status="Atual (Este Nó)"
        fi
        NODE_LIST+=("$node" "$status")
    done < <(pvesh get /nodes --output-format json 2>/dev/null | grep -o '"node":"[^"]*"' | cut -d'"' -f4 || pvecm nodes 2>/dev/null | awk 'NR>2 {print $NF}')

    if [ ${#NODE_LIST[@]} -ge 4 ]; then
        TARGET_NODE=$(whiptail --title "$TITLE - Seleção de Cluster" \
            --menu "Ambiente em CLUSTER detectado!\nUse as SETAS para escolher em qual máquina/nó deseja criar o ProxPXE:" 16 70 6 \
            "${NODE_LIST[@]}" 3>&1 1>&2 2>&3) || exit 1
        
        # Se escolheu outro nó do cluster, executa o assistente no nó de destino via SSH
        if [ "$TARGET_NODE" != "$CURRENT_NODE" ]; then
            clear
            echo -e "${CYAN}Conectando ao nó ${BOLD}$TARGET_NODE${NC}${CYAN} do cluster para executar a instalação...${NC}"
            ssh -t "root@$TARGET_NODE" "bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/FelipeMzero/ProxPXE/main/proxmox/create-ct.sh?\\$(date +%s))\""
            exit 0
        fi
    fi
fi

# ==============================================================================
# 3. CONTAINER ID (VERIFICAÇÃO E VALIDAÇÃO DE DUPLICIDADE)
# ==============================================================================
NEXT_ID=$(pvesh get /cluster/nextid 2>/dev/null || echo "110")
CT_ID=""

while true; do
    CT_ID=$(whiptail --title "$TITLE - ID do Container" \
        --inputbox "Informe o ID numérico para o Container LXC:" 10 60 "$NEXT_ID" 3>&1 1>&2 2>&3) || exit 1

    # Valida se é número
    if ! [[ "$CT_ID" =~ ^[0-9]+$ ]]; then
        whiptail --title "Erro" --msgbox "O ID do container deve ser apenas números! Tente novamente." 9 55
        continue
    fi

    # Verifica se já existe localmente ou no cluster
    ID_EXISTS=0
    if pct status "$CT_ID" >/dev/null 2>&1; then
        ID_EXISTS=1
    elif pvesh get /cluster/resources --type vm 2>/dev/null | grep -w "\"vmid\":$CT_ID" >/dev/null 2>&1; then
        ID_EXISTS=1
    fi

    if [ "$ID_EXISTS" -eq 1 ]; then
        NEXT_SUGGESTION=$(pvesh get /cluster/nextid 2>/dev/null || echo "115")
        whiptail --title "Container ID em Uso" \
            --msgbox "O Container ID $CT_ID já existe e está em uso neste nó ou cluster!\n\nPor favor, escolha outro número ou utilize o próximo ID livre sugerido: $NEXT_SUGGESTION." 11 65
        NEXT_ID="$NEXT_SUGGESTION"
    else
        break
    fi
done

# ==============================================================================
# 4. HOSTNAME DO CONTAINER
# ==============================================================================
CT_HOSTNAME=$(whiptail --title "$TITLE - Hostname" \
    --inputbox "Digite o nome da máquina (Hostname) para o ProxPXE:" 10 60 "proxpxe" 3>&1 1>&2 2>&3) || exit 1
CT_HOSTNAME=${CT_HOSTNAME:-"proxpxe"}

# ==============================================================================
# 5. ESCOLHA DE STORAGE COM AS SETAS DO TECLADO
# ==============================================================================
STORAGE_MENU=()
while IFS= read -r sname; do
    [ -n "$sname" ] || continue
    # Obtém tipo e espaço livre
    sinfo=$(pvesm status -storage "$sname" 2>/dev/null | awk 'NR>1 {print $2 ", Livre: " int($6/1024/1024) " GB"}' || echo "Storage Proxmox")
    STORAGE_MENU+=("$sname" "$sinfo")
done < <(pvesm status -content rootdir 2>/dev/null | awk 'NR>1 {print $1}')

# Fallback se não encontrar
if [ ${#STORAGE_MENU[@]} -eq 0 ]; then
    STORAGE_MENU=("local-lvm" "LVM-Thin Padrão" "local" "Diretório Local")
fi

CT_STORAGE=$(whiptail --title "$TITLE - Storage de Armazenamento" \
    --menu "Use as SETAS (↑ ↓) do teclado para escolher onde o disco do CT será instalado:" 17 72 6 \
    "${STORAGE_MENU[@]}" 3>&1 1>&2 2>&3) || exit 1

# ==============================================================================
# 6. QUANTIDADE DE DISCO, MEMÓRIA RAM E SWAP
# ==============================================================================
CT_DISK=$(whiptail --title "$TITLE - Armazenamento" \
    --inputbox "Informe o tamanho do disco em GB para o ProxPXE:" 10 60 "32" 3>&1 1>&2 2>&3) || exit 1
CT_DISK=${CT_DISK:-32}

CT_RAM=$(whiptail --title "$TITLE - Memória RAM" \
    --inputbox "Informe a quantidade de memória RAM em MB:" 10 60 "2048" 3>&1 1>&2 2>&3) || exit 1
CT_RAM=${CT_RAM:-2048}

CT_SWAP=$(whiptail --title "$TITLE - Memória SWAP" \
    --inputbox "Informe a quantidade de SWAP em MB:" 10 60 "1024" 3>&1 1>&2 2>&3) || exit 1
CT_SWAP=${CT_SWAP:-1024}

CT_CORES=2

# ==============================================================================
# 7. ESCOLHA DA BRIDGE DE REDE COM AS SETAS DO TECLADO
# ==============================================================================
BRIDGE_MENU=()
while IFS= read -r br; do
    [ -n "$br" ] || continue
    BRIDGE_MENU+=("$br" "Interface Bridge Proxmox")
done < <(ip -o link show type bridge 2>/dev/null | awk -F': ' '{print $2}' || grep -E '^[[:space:]]*iface[[:space:]]+vmbr' /etc/network/interfaces 2>/dev/null | awk '{print $2}')

if [ ${#BRIDGE_MENU[@]} -eq 0 ]; then
    BRIDGE_MENU=("vmbr0" "Bridge Padrão Proxmox")
fi

CT_BRIDGE=$(whiptail --title "$TITLE - Bridge de Rede" \
    --menu "Use as SETAS (↑ ↓) para escolher a Bridge de Rede:" 15 65 5 \
    "${BRIDGE_MENU[@]}" 3>&1 1>&2 2>&3) || exit 1

# ==============================================================================
# 8. CONFIGURAÇÃO DE IP (DHCP RANGE OU IP ESPECÍFICO FIXO)
# ==============================================================================
NET_CHOICE=$(whiptail --title "$TITLE - Endereço IP" \
    --menu "Como deseja configurar o endereço IP do ProxPXE?" 14 72 4 \
    "1" "DHCP Automático (Pega da range da rede - Recomendado)" \
    "2" "IP Específico / Fixo (Configurar manualmente IP, Gateway e DNS)" \
    3>&1 1>&2 2>&3) || exit 1

STATIC_IP=""
STATIC_GW=""
STATIC_DNS="1.1.1.1"

# Auto-detecta gateway e rede do host Proxmox para preenchimento inteligente
HOST_DEFAULT_GW=$(ip route show default 2>/dev/null | awk '{print $3}' | head -n1 || true)
HOST_DEFAULT_GW=${HOST_DEFAULT_GW:-"10.172.0.1"}

DEF_IFACE=$(ip route show default 2>/dev/null | awk '{print $5}' | head -n1 || echo "vmbr0")
HOST_IP_CIDR=$(ip -o -4 addr show dev "$DEF_IFACE" scope global 2>/dev/null | awk '{print $4}' | head -n1 || true)
if [ -n "$HOST_IP_CIDR" ]; then
    SUBNET_PREFIX="${HOST_IP_CIDR%/*}"
    CIDR_MASK="${HOST_IP_CIDR#*/}"
    IP_BASE=$(echo "$SUBNET_PREFIX" | awk -F. '{print $1"."$2"."$3}')
    SUGGESTED_IP="${IP_BASE}.220/${CIDR_MASK}"
else
    SUGGESTED_IP="10.172.0.220/16"
fi

if [ "$NET_CHOICE" = "2" ]; then
    STATIC_IP=$(whiptail --title "$TITLE - IP Estático" \
        --inputbox "Informe o IP estático com máscara CIDR:\n(Ex: 10.172.0.220/16 para máscara 255.255.0.0)" 10 65 "$SUGGESTED_IP" 3>&1 1>&2 2>&3) || exit 1

    STATIC_GW=$(whiptail --title "$TITLE - Gateway" \
        --inputbox "Informe o Gateway padrão da sua rede:" 10 65 "$HOST_DEFAULT_GW" 3>&1 1>&2 2>&3) || exit 1

    STATIC_DNS=$(whiptail --title "$TITLE - Servidor DNS" \
        --inputbox "Informe o Servidor DNS:" 10 65 "$HOST_DEFAULT_GW" 3>&1 1>&2 2>&3) || exit 1

    NET_CONFIG="name=eth0,bridge=${CT_BRIDGE},ip=${STATIC_IP},gw=${STATIC_GW}"
else
    NET_CONFIG="name=eth0,bridge=${CT_BRIDGE},ip=dhcp"
fi

# ==============================================================================
# 9. ARMAZENAMENTO DE ISOS (PASTA PRÓPRIA + COMPARTILHAMENTO DO PROXMOX)
# ==============================================================================
PVE_ISO_DIR="/var/lib/vz/template/iso"
BIND_ISO=0

if [ -d "$PVE_ISO_DIR" ]; then
    BIND_ISO=1
    whiptail --title "$TITLE - Armazenamento de ISOs Híbrido" \
        --msgbox "Armazenamento Híbrido Configurado Automaticamente:\n\n1. Pasta Própria (/data/iso):\n   Criada no storage '$CT_STORAGE' pronta para Upload pelo Navegador e Download via Link (URL).\n\n2. Compartilhamento Proxmox (/data/proxmox-iso):\n   Monta as ISOs já existentes de $PVE_ISO_DIR diretamente no container, economizando espaço em disco!\n\nAmbos os diretórios serão unificados no Menu de Boot e no Painel Web!" 16 75 || true
fi

# ==============================================================================
# 10. CONFIRMAÇÃO RESUMO ANTES DA INSTALAÇÃO
# ==============================================================================
SUMMARY="Confira os dados da instalação:\n\n"
SUMMARY+="  • Nó de Destino:   $TARGET_NODE\n"
SUMMARY+="  • ID do Container: $CT_ID\n"
SUMMARY+="  • Hostname:        $CT_HOSTNAME\n"
SUMMARY+="  • Storage:         $CT_STORAGE\n"
SUMMARY+="  • Armazenamento:   $CT_DISK GB\n"
SUMMARY+="  • RAM / SWAP:      $CT_RAM MB / $CT_SWAP MB\n"
SUMMARY+="  • Bridge de Rede:  $CT_BRIDGE\n"
if [ "$NET_CHOICE" = "2" ]; then
    SUMMARY+="  • Modo de IP:      Fixo ($STATIC_IP)\n"
else
    SUMMARY+="  • Modo de IP:      DHCP Automático\n"
fi
if [ "$BIND_ISO" -eq 1 ]; then
    SUMMARY+="  • Pasta de ISOs:   HÍBRIDA (Própria no CT + Compartilhada do PVE)\n\n"
else
    SUMMARY+="  • Pasta de ISOs:   Própria (/data/iso no storage $CT_STORAGE)\n\n"
fi
SUMMARY+="Deseja iniciar a criação do Container LXC agora?"

if ! whiptail --title "$TITLE - Confirmação" --yesno "$SUMMARY" 19 65; then
    clear
    echo -e "${YELLOW}Instalação cancelada pelo usuário.${NC}"
    exit 0
fi

# ==============================================================================
# EXECUÇÃO DA INSTALAÇÃO
# ==============================================================================
clear
echo -e "${CYAN}==============================================================================${NC}"
echo -e "${WHITE}${BOLD}       PROXPXE - CRIANDO E CONFIGURANDO O CONTAINER LXC NO PROXMOX VE         ${NC}"
echo -e "${CYAN}==============================================================================${NC}"

# 1. Download do Template Debian 12
echo -e "\n${BLUE}[1/5] Atualizando lista de templates e verificando Debian 12...${NC}"
pveam update >/dev/null 2>&1 || true

TEMPLATE_STORAGE=$(pvesm status -content vztmpl 2>/dev/null | awk 'NR>1 {print $1}' | head -n1)
TEMPLATE_STORAGE=${TEMPLATE_STORAGE:-$CT_STORAGE}

DEBIAN_TEMPLATE=$(pveam available --section system 2>/dev/null | grep "debian-12-standard" | awk '{print $2}' | sort -V | tail -n1)

if [ -z "$DEBIAN_TEMPLATE" ]; then
    echo -e "${RED}[ERRO] Não foi possível localizar o template Debian 12 oficial.${NC}"
    exit 1
fi

LOCAL_TEMPLATE_PATH="/var/lib/vz/template/cache/${DEBIAN_TEMPLATE}"
if [ ! -f "$LOCAL_TEMPLATE_PATH" ]; then
    echo -e "${CYAN}Baixando template Debian 12 oficial (${DEBIAN_TEMPLATE})...${NC}"
    pveam download "$TEMPLATE_STORAGE" "$DEBIAN_TEMPLATE"
else
    echo -e "${GREEN}[OK] Template Debian 12 já disponível em cache local.${NC}"
fi

# 2. Criação do Container
echo -e "\n${BLUE}[2/5] Criando Container LXC (CT $CT_ID - $CT_HOSTNAME) no storage $CT_STORAGE...${NC}"
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
    -unprivileged 0 \
    -password "admin"

if [ "$NET_CHOICE" = "2" ] && [ -n "${STATIC_DNS:-}" ]; then
    pct set "$CT_ID" -nameserver "$STATIC_DNS"
fi

if [ "$BIND_ISO" -eq 1 ]; then
    echo -e "${GREEN}[OK] Montando pasta de ISOs do Proxmox ($PVE_ISO_DIR) em /data/proxmox-iso...${NC}"
    pct set "$CT_ID" -mp0 "${PVE_ISO_DIR},mp=/data/proxmox-iso"
fi
echo -e "${GREEN}[OK] Pasta de ISOs própria (/data/iso) ativa no storage $CT_STORAGE (Upload/Link prontos)...${NC}"
echo -e "${GREEN}[OK] Container LXC $CT_ID criado com sucesso!${NC}"

# 3. Iniciar Container
echo -e "\n${BLUE}[3/5] Inicializando Container LXC e aguardando conexão de rede...${NC}"
pct start "$CT_ID"

echo -e "Aguardando conectividade de rede do container..."
for i in {1..30}; do
    if pct exec "$CT_ID" -- ping -c 1 1.1.1.1 >/dev/null 2>&1; then
        echo -e "${GREEN}[OK] Rede conectada com sucesso!${NC}"
        break
    fi
    sleep 1
done

# Configura usuário e senha do sistema operacional Linux (admin:admin e root:admin)
echo -e "Configurando credenciais do sistema Linux (usuário admin:admin e root:admin)..."
pct exec "$CT_ID" -- bash -c "
    echo 'root:admin' | chpasswd
    id admin &>/dev/null || useradd -m -s /bin/bash admin 2>/dev/null || true
    echo 'admin:admin' | chpasswd
    usermod -aG sudo admin 2>/dev/null || true
"

# Garante estrutura de pastas e permissões no armazenamento para Upload e Download
echo -e "Configurando permissões do armazenamento (/data/iso e /data/proxmox-iso)..."
pct exec "$CT_ID" -- mkdir -p /data/iso /data/proxmox-iso /data/extracted /data/config /data/theme
pct exec "$CT_ID" -- chown -R www-data:www-data /data 2>/dev/null || true
pct exec "$CT_ID" -- chmod -R 777 /data/iso /data/config /data/extracted 2>/dev/null || true

# 4. Clonar e Instalar ProxPXE
echo -e "\n${BLUE}[4/5] Clonando e instalando componentes do ProxPXE dentro do Container...${NC}"
pct exec "$CT_ID" -- apt-get update -y
pct exec "$CT_ID" -- apt-get install -y git curl

pct exec "$CT_ID" -- rm -rf /tmp/pxe-setup
pct exec "$CT_ID" -- git clone https://github.com/FelipeMzero/ProxPXE.git /tmp/pxe-setup
pct exec "$CT_ID" -- bash /tmp/pxe-setup/install.sh
echo -e "${GREEN}[OK] ProxPXE e serviços configurados com sucesso!${NC}"

# 5. Obtém IP Final
echo -e "\n${BLUE}[5/5] Detectando endereço IP do Container ProxPXE...${NC}"
CT_FINAL_IP=""
for i in {1..20}; do
    CT_FINAL_IP=$(pct exec "$CT_ID" -- ip -4 -o addr show eth0 2>/dev/null | awk '{print $4}' | cut -d/ -f1 | head -n1 || true)
    if [ -n "$CT_FINAL_IP" ] && [ "$CT_FINAL_IP" != "127.0.0.1" ]; then
        break
    fi
    sleep 1
done

if [ -z "$CT_FINAL_IP" ]; then
    CT_FINAL_IP=$(pct exec "$CT_ID" -- hostname -I 2>/dev/null | awk '{print $1}' || echo "")
fi

if [ -z "$CT_FINAL_IP" ]; then
    CT_FINAL_IP="<IP-DO-CONTAINER>"
fi

# Tela final em Whiptail
FINAL_MSG="Instalação do ProxPXE concluída com sucesso!\n\n"
FINAL_MSG+="  • Container ID:         $CT_ID ($CT_HOSTNAME)\n"
FINAL_MSG+="  • Status:               ATIVO E RODANDO\n"
FINAL_MSG+="  • Painel de Controle:   http://$CT_FINAL_IP\n"
FINAL_MSG+="  • Usuário (Console/Web): admin (ou root)\n"
FINAL_MSG+="  • Senha (Console/Web):   admin\n"
if [ "$BIND_ISO" -eq 1 ]; then
    FINAL_MSG+="  • Armazenamento ISOs:   HÍBRIDO (/data/iso Próprio + /data/proxmox-iso PVE)\n"
else
    FINAL_MSG+="  • Armazenamento ISOs:   Pasta Própria (/data/iso no storage $CT_STORAGE)\n"
fi
FINAL_MSG+="  • Modo de Rede PXE:     ProxyDHCP (Porta 4011 - Seguro!)\n\n"
FINAL_MSG+="Você já pode abrir http://$CT_FINAL_IP no seu navegador para gerenciar as ISOs e temas!\n"
FINAL_MSG+="Para dar boot nas máquinas clientes, tecle F12 e selecione Network Boot (PXE)."

whiptail --title "$TITLE - Instalação Concluída!" --msgbox "$FINAL_MSG" 19 74 || true

# Exibe o resumo final destacado na tela sem limpar o histórico do terminal
echo -e "\n${GREEN}==============================================================================${NC}"
echo -e "${GREEN}${BOLD}           PARABÉNS! PROXPXE INSTALADO COM SUCESSO NO PROXMOX VE!             ${NC}"
echo -e "${GREEN}==============================================================================${NC}"
echo -e "  Status do Container:      ${GREEN}${BOLD}ATIVO E OPERACIONAL${NC} (CT ${BOLD}$CT_ID${NC} - ${BOLD}$CT_HOSTNAME${NC})"
echo -e "  Storage Utilizado:        ${CYAN}${CT_STORAGE} (${CT_DISK} GB)${NC}"
echo -e "  Memória RAM / SWAP:       ${CYAN}${CT_RAM} MB RAM / ${CT_SWAP} MB SWAP${NC}"
if [ "$BIND_ISO" -eq 1 ]; then
    echo -e "  Armazenamento ISOs:       ${GREEN}HÍBRIDO UNIFICADO${NC}"
    echo -e "                            • Próprio: /data/iso (Upload Web e Download por URL)"
    echo -e "                            • Proxmox: /data/proxmox-iso (Montado de ${PVE_ISO_DIR})"
else
    echo -e "  Armazenamento ISOs:       ${GREEN}Pasta Própria (/data/iso no storage ${CT_STORAGE})${NC}"
    echo -e "                            ${CYAN}Upload via Web e Download por Link URL ativados!${NC}"
fi
echo -e "------------------------------------------------------------------------------"
echo -e "  ${WHITE}${BOLD}🌐 ACESSO AO PAINEL WEB E CONSOLE DO CONTAINER:${NC}"
echo -e "     URL Web:               ${GREEN}${BOLD}http://${CT_FINAL_IP}${NC}"
echo -e "     Usuário (Web/Console): ${BOLD}admin${NC} (ou root)"
echo -e "     Senha (Web/Console):   ${BOLD}admin${NC}"
echo -e "------------------------------------------------------------------------------"
echo -e "  ${YELLOW}${BOLD}📡 INICIALIZAÇÃO DE COMPUTADORES POR REDE (PXE):${NC}"
echo -e "     Modo de Operação:      ${YELLOW}ProxyDHCP (Porta 4011)${NC} - Não altera o roteador da sua rede!"
echo -e "     Como usar:             Ligue qualquer máquina e pressione ${CYAN}${BOLD}F12${NC} (Network Boot)"
echo -e "${GREEN}==============================================================================${NC}\n"
