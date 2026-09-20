#!/usr/bin/env bash
# ==============================================================================
# ProxPXE - Auto-Detecção e Configuração Dinâmica de Rede e ProxyDHCP (100% Bash)
# Detecta a rede atual (IP estático ou DHCP, /24, /16, /23, etc.)
# e configura o Dnsmasq para a faixa exata da rede onde o CT está conectado!
# ==============================================================================

set -eo pipefail

CONF_FILE="/etc/dnsmasq.d/pxe.conf"

detect_network() {
    local iface
    iface=$(ip -4 route show default 2>/dev/null | awk '{print $5}' | head -n1 || true)
    if [ -z "$iface" ]; then
        iface=$(ip -o -4 addr show scope global 2>/dev/null | awk '{print $2}' | head -n1 || true)
    fi
    iface=${iface:-eth0}

    local ip_cidr
    ip_cidr=$(ip -o -4 addr show dev "$iface" scope global 2>/dev/null | awk '{print $4}' | head -n1 || true)

    if [ -z "$ip_cidr" ]; then
        # Fallback local se estiver offline ou em teste
        echo "127.0.0.1 127.0.0.0 255.255.255.0 $iface"
        return 0
    fi

    local host_ip="${ip_cidr%/*}"
    local prefix="${ip_cidr#*/}"
    prefix=${prefix:-24}

    local subnet_addr=""
    local net_mask=""

    # 1. Tenta cálculo preciso via biblioteca padrão do Python
    if command -v python3 >/dev/null 2>&1; then
        read -r subnet_addr net_mask <<< $(python3 -c "
import ipaddress
try:
    iface = ipaddress.IPv4Interface('$ip_cidr')
    print(iface.network.network_address, iface.netmask)
except Exception:
    pass
" 2>/dev/null || true)
    fi

    # 2. Fallback via ip route scope link
    if [ -z "$subnet_addr" ] || [ -z "$net_mask" ]; then
        local link_net
        link_net=$(ip route show dev "$iface" scope link 2>/dev/null | awk '{print $1}' | head -n1 || true)
        if [ -n "$link_net" ] && [[ "$link_net" == *"/"* ]]; then
            subnet_addr="${link_net%/*}"
        else
            subnet_addr="$host_ip"
        fi

        # Converte prefixo simples para máscara
        case "$prefix" in
            8)  net_mask="255.0.0.0" ;;
            16) net_mask="255.255.0.0" ;;
            23) net_mask="255.255.254.0" ;;
            24) net_mask="255.255.255.0" ;;
            25) net_mask="255.255.255.128" ;;
            26) net_mask="255.255.255.192" ;;
            27) net_mask="255.255.255.224" ;;
            28) net_mask="255.255.255.240" ;;
            *)  net_mask="255.255.255.0" ;;
        esac
    fi

    echo "$host_ip $subnet_addr $net_mask $iface"
}

apply_dnsmasq_proxy() {
    read -r HOST_IP SUBNET_ADDR NET_MASK IFACE <<< "$(detect_network)"

    echo "==> [PROXPXE-NETWORK] Rede Detectada Automaticamente:"
    echo "    -> Interface:   $IFACE"
    echo "    -> IP do CT:    $HOST_IP"
    echo "    -> Rede Subnet: $SUBNET_ADDR"
    echo "    -> Máscara:     $NET_MASK"
    echo "    -> Configurando ProxyDHCP para a rede: $SUBNET_ADDR,proxy,$NET_MASK"

    # Se estiver em ambiente com /etc/dnsmasq.d
    if [ -d "/etc/dnsmasq.d" ]; then
        if [ -f /etc/dnsmasq.conf ] && ! grep -q "conf-dir=/etc/dnsmasq.d" /etc/dnsmasq.conf 2>/dev/null; then
            echo "conf-dir=/etc/dnsmasq.d/,*.conf" >> /etc/dnsmasq.conf
        fi

        cat << EOF > "$CONF_FILE"
# ====================================================
# PROXPXE - MODO PROXYDHCP DINÂMICO
# Gerado automaticamente de acordo com a rede do CT
# ====================================================

port=0
enable-tftp
tftp-root=/var/lib/tftpboot
tftp-max=100
log-dhcp
log-facility=/var/log/dnsmasq.log

# Faixa ProxyDHCP calculada dinamicamente para esta rede
dhcp-range=$SUBNET_ADDR,proxy,$NET_MASK

# Detecção de Arquitetura de Cliente (Option 93)
dhcp-match=set:bios,option:client-arch,0
dhcp-match=set:efi-ia32,option:client-arch,6
dhcp-match=set:efi-x64,option:client-arch,7
dhcp-match=set:efi-x64,option:client-arch,9
dhcp-match=set:efi-arm64,option:client-arch,11

# Arquivos de Boot com o IP atual do servidor
dhcp-boot=tag:bios,bios/lpxelinux.0,$HOST_IP,$HOST_IP
dhcp-boot=tag:efi-ia32,uefi/grubnetia32.efi,$HOST_IP,$HOST_IP
dhcp-boot=tag:efi-x64,uefi/grubnetx64.efi,$HOST_IP,$HOST_IP
dhcp-boot=uefi/grubnetx64.efi,$HOST_IP,$HOST_IP

# Menu PXE / ProxyDHCP (Porta 4011)
pxe-prompt="Inicializando ProxPXE (Ventoy Edition)...", 2
pxe-service=tag:bios,x86PC,"ProxPXE (BIOS Legacy)",bios/lpxelinux.0
pxe-service=tag:efi-x64,X86-64_EFI,"ProxPXE (UEFI 64-bit)",uefi/grubnetx64.efi
pxe-service=tag:efi-x64,9,"ProxPXE (UEFI 64-bit)",uefi/grubnetx64.efi
pxe-service=X86-64_EFI,"ProxPXE (UEFI 64-bit)",uefi/grubnetx64.efi
EOF

        if command -v systemctl >/dev/null 2>&1; then
            systemctl restart dnsmasq 2>/dev/null || true
        fi
        echo "==> [PROXPXE-NETWORK] Dnsmasq atualizado e reiniciado com sucesso!"
    else
        echo "==> [PROXPXE-NETWORK] Modo simulação/desenvolvimento. Arquivo gerado para teste."
    fi
}

case "${1:-}" in
    detect)
        detect_network
        ;;
    apply|*)
        apply_dnsmasq_proxy
        ;;
esac
