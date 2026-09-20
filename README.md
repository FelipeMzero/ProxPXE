# ProxPXE - Servidor PXE Estilo Ventoy para Proxmox VE (100% Bash) 🚀

O **ProxPXE** é um sistema completo e ultraleve de **Boot de Rede PXE** desenvolvido **100% em Shell Script (Bash)**, projetado especificamente para rodar dentro de um **Container LXC no Proxmox VE**. Apresenta um **menu gráfico de inicialização estilo Ventoy** (Full HD 1920x1080), modo seguro **ProxyDHCP** (não interfere no seu roteador atual), monitoramento automático de pastas e um moderno **Painel de Controle Web**.

---

## ⚡ Instalação Rápida no Proxmox VE (Comando Único)

Abra o **Shell do seu nó Proxmox VE (PVE)** e execute o comando abaixo:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/FelipeMzero/ProxPXE/main/proxmox/create-ct.sh)"
```

> **Dica:** Para forçar o download sem cache da versão mais recente, você também pode usar:
> ```bash
> bash -c "$(curl -fsSL "https://raw.githubusercontent.com/FelipeMzero/ProxPXE/main/proxmox/create-ct.sh?$(date +%s)")"
> ```

### 🖥️ O que o assistente interativo (`whiptail`) configura:

1. **Navegação com Setas (↑ ↓) e Teclado:** Seleção fácil de opções sem necessidade de digitar caminhos manuais.
2. **Suporte a Cluster Proxmox:** Se estiver em cluster PVE, permite escolher em qual nó o ProxPXE será provisionado.
3. **Verificação de Container ID Livre:** Sugere o próximo ID disponível no cluster e impede conflito de IDs duplicados.
4. **Seleção de Storage com Setas:** Lista os storages disponíveis (`local-lvm`, `hrmj-vm`, `local-zfs`, etc.) com tamanho livre em GB.
5. **Hardware:** Tamanho do Disco (GB), Memória RAM (MB) e SWAP (MB).
6. **Seleção de Bridge de Rede com Setas:** Escolha a interface de rede bridge (`vmbr0`, `vmbr1`, etc.).
7. **Modo de Endereço IP:**
   - **Opção 1:** Usar a **range da rede via DHCP** automaticamente (Recomendado).
   - **Opção 2:** Configurar **IP Fixo/Estático** (IP com máscara CIDR, Gateway e Servidor DNS).
8. **Configuração do Armazenamento de ISOs:**
   - **Opção 1 (Recomendado):** Criar pasta própria (`/data/iso`) no storage escolhido — 100% pronta para **Upload pelo Navegador** e **Download direto por Link/URL**.
   - **Opção 2:** Compartilhar a pasta de ISOs nativa do Proxmox (`/var/lib/vz/template/iso`) para economizar espaço em disco.

---

## 🔄 Como Atualizar um Container Existente (Sem Recriar)

Se você já possui o container criado e quer apenas atualizar a aplicação e o painel web para a versão mais recente, execute no **Shell do Proxmox** (substitua `<ID>` pelo número do seu CT, ex: `100`):

```bash
pct exec <ID> -- bash -c "rm -rf /tmp/pxe-setup && git clone https://github.com/FelipeMzero/ProxPXE.git /tmp/pxe-setup && bash /tmp/pxe-setup/install.sh"
```

### 💿 Como Vincular a Pasta de ISOs do Proxmox no Container Existente

Se o container já está criado e você quer que ele enxergue as ISOs salvas no Proxmox VE (seja em `local`, `hrmj-migration`, etc.), execute no **Shell do Proxmox**:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/FelipeMzero/ProxPXE/main/proxmox/mount-iso.sh)"
```
*(O assistente localiza automaticamente todos os storages do Proxmox com ISOs, ajusta as permissões, configura o ponto de montagem `mp0`, reinicia o container para aplicar o mount do LXC e indexa todas as ISOs).*

---

## 🔐 Acesso ao Container & Credenciais Padrão

- **Painel Web:** `http://<IP_DO_CONTAINER>`
- **Console Proxmox / SSH:**
  - **Usuário:** `admin` (ou `root`)
  - **Senha:** `admin`
- **Usuário do Painel Web:** `admin`
- **Senha do Painel Web:** `admin`

*(Você pode alterar as credenciais a qualquer momento).*

---

## 🌟 Principais Recursos do ProxPXE

- **Tema Claro Editável (.ini) - Hospital Regional Menino Jesus:**
  - Identidade visual limpa em **Branco e Azul** inspirada no padrão hospitalar.
  - **100% Customizável via arquivo `.ini`:** Todas as cores, fontes, títulos e resolução ficam em `/data/config/theme.ini`. Qualquer pessoa pode abrir e editar!
  - **Editor Integrado no Painel Web:** Altere o arquivo `.ini` diretamente no navegador e aplique com 1 clique!
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
