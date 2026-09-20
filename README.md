# ProxPXE - Servidor PXE Estilo Ventoy para Proxmox VE (100% Bash) 🚀

O **ProxPXE** é um sistema completo e ultraleve de **Boot de Rede PXE** desenvolvido **100% em Shell Script (Bash)**, projetado especificamente para rodar dentro de um **Container LXC no Proxmox VE**. Apresenta um **menu gráfico de inicialização estilo Ventoy** (Full HD 1920x1080), modo seguro **ProxyDHCP** (não interfere no seu roteador atual), monitoramento automático de pastas e um moderno **Painel de Controle Web**.

---

## ⚡ Instalação Rápida no Proxmox VE (Comando Único)

Abra o **Shell do seu nó Proxmox VE (PVE)** e execute o comando abaixo:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/FelipeMzero/ProxPXE/main/proxmox/create-ct.sh)"
```

O assistente interativo perguntará detalhadamente:
1. **Container ID e Hostname:** Sugere o próximo ID livre (ex: `110`) e nome `proxpxe`.
2. **Onde vai ser instalado o CT (Storage):** Lista todos os storages disponíveis no Proxmox (`local-lvm`, `local-zfs`, etc.).
3. **Armazenamento:** Quantidade de disco em GB (padrão: `32 GB`).
4. **Memória RAM:** Quantidade de memória RAM em MB (padrão: `2048 MB`).
5. **Memória SWAP:** Quantidade de memória SWAP em MB (padrão: `512 MB`).
6. **Rede e Endereço IP:**
   - Opção 1: Usar a **range da sua rede local para pegar o IP via DHCP automaticamente** (Recomendado).
   - Opção 2: Definir um **IP específico / fixo** manualmente (IP/CIDR, Gateway e Servidor DNS).
7. **Compartilhamento de ISOs do Proxmox:** Pergunta se deseja montar `/var/lib/vz/template/iso` diretamente no container, economizando espaço em disco!

---

## 🔐 Acesso ao Painel Web & Credenciais Padrão

Acesse no navegador: **`http://<IP_DO_CONTAINER>`**

- **Usuário Padrão:** `admin`
- **Senha Padrão:** `admin`

*(Você pode alterar as credenciais diretamente pelo painel a qualquer momento).*

---

## 🌟 Principais Recursos do ProxPXE

- **Fonte Padrão: Outfit:**
  - Fonte moderna e geométrica configurada como padrão tanto no **Menu Ventoy (GRUB2)** quanto na **Interface Web**.
- **Descarregar ISO Diretamente via URL:**
  - Cole o link de download direto de qualquer ISO (Ubuntu, Windows, Proxmox, Debian, etc.).
  - O download ocorre em segundo plano com barra de progresso em tempo real, velocidade (MB/s) e opção de cancelamento.
- **Upload Direto de ISOs:**
  - Envie arquivos `.iso` ou `.img` direto do seu computador com barra de progresso.
- **Análise Detalhada de Disco (/data):**
  - Gráficos de uso do armazenamento, tamanho ocupado pelas ISOs, kernels de live-boot e espaço disponível.
- **Computadores Conectados & Status de Instalação em Tempo Real (%):**
  - Visualize os computadores conectados na rede por IP, MAC e Hostname.
  - Acompanhe a **porcentagem exata de instalação (%)** e a transferência da imagem em tempo real!
- **Tela de Boot Estilo Ventoy:**
  - Baseada no motor gráfico `gfxmenu` do GRUB2 em alta resolução (1920x1080 Full HD).
  - Suporte a **UEFI (x86_64)** e **Legacy BIOS**.
- **Modo Seguro ProxyDHCP (Porta 4011):**
  - Não altera nem interfere no roteador da sua casa ou empresa. Responde apenas a solicitações de boot por rede.

---

## 📁 Onde Colocar seus Arquivos (ISOs, Logos e Fontes)

Todas as pastas de customização ficam centralizadas em `/data`:

| Pasta / Arquivo | O que colocar aqui | Formatos |
| :--- | :--- | :--- |
| `/data/iso/` | Suas imagens de instalação de sistemas operacionais. | `.iso`, `.img` |
| `/data/theme/logo.png` | Sua imagem de Logotipo exibida no topo do menu de boot. | `.png` (280x68 aprox.) |
| `/data/theme/background.png` | Imagem de papel de parede de fundo do menu de boot. | `.png` (1920x1080) |
| `/data/theme/fonts/` | Fontes tipográficas utilizadas nos textos do menu. | `.pf2` ou `.ttf` (convertidas auto) |
| `/data/theme/icons/` | Ícones para os sistemas operacionais (Windows, Proxmox, Debian, etc.). | `.png` (32x32) |
| `/data/theme/theme.txt` | Arquivo de estilização e coordenadas do menu Ventoy. | Texto GRUB2 |

---

## 💻 Como dar Boot nas Máquinas Clientes

Como o ProxPXE opera em **ProxyDHCP**, você não precisa configurar nada no seu roteador:

1. Conecte o computador de destino na mesma rede local (cabo Ethernet).
2. Ligue a máquina e pressione a tecla de seleção de boot (Boot Menu):
   - **Dell:** `F12`
   - **HP:** `F9` ou `ESC`
   - **Lenovo:** `F12`
   - **Asus / Gigabyte:** `F8` ou `F12`
   - **Placas-mãe diversas:** `F11` ou `F12`
3. Escolha **Network Boot / IPv4 PXE**.
4. O menu gráfico do ProxPXE (estilo Ventoy) será carregado com a sua logo e a lista de ISOs para iniciar!

---

## 🛠️ Ferramenta de Linha de Comando (`proxpxe` / `pxe-cli`)

Dentro do container, você conta com um comando CLI exclusivo para gerenciar o ProxPXE:

```bash
# Ver status dos serviços e endereço IP
proxpxe status

# Forçar reescaneamento das ISOs e regeneração dos menus
proxpxe scan

# Recompilar layout do tema e converter fontes
proxpxe theme

# Listar todas as ISOs disponíveis
proxpxe list

# Alternar modo DHCP (proxy ou standalone)
proxpxe mode proxy
```

---

## 📂 Estrutura do Repositório

```text
├── proxmox/
│   └── create-ct.sh         # Script executado no shell do Proxmox para criar o CT
├── install.sh               # Script de instalação do container em Bash
├── scripts/
│   ├── pxe-scan.sh          # Escaneador de ISOs e gerador de grub.cfg / ipxe
│   ├── pxe-theme.sh         # Gerenciador do tema Ventoy e fontes .pf2
│   ├── pxe-watch.sh         # Daemon que monitora a pasta /data/iso e atualiza auto
│   ├── pxe-api.sh           # API em Bash CGI para o painel web
│   └── pxe-cli.sh           # Interface de linha de comando (proxpxe)
├── web/
│   └── index.html           # Painel Web com Simulador ProxPXE Full HD
├── configs/
│   ├── dnsmasq.conf         # Configuração ProxyDHCP e TFTP
│   ├── nginx.conf           # Servidor HTTP otimizado para streaming de ISOs
│   └── pxe-watcher.service  # Unidade systemd do daemon de monitoramento
└── data/
    └── theme/               # Assets padrão (logo, background, theme.txt)
```

---

## 📜 Licença

Distribuído sob licença MIT. Sinta-se livre para usar, customizar e contribuir!
