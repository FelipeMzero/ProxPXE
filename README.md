# ProxPXE - Servidor PXE Estilo Ventoy para Proxmox VE (100% Bash) 🚀

O **ProxPXE** é um sistema completo e ultraleve de **Boot de Rede PXE** desenvolvido **100% em Shell Script (Bash)**, projetado especificamente para rodar dentro de um **Container LXC no Proxmox VE**. Apresenta um **menu gráfico de inicialização estilo Ventoy** (Full HD 1920x1080), modo seguro **ProxyDHCP** (não interfere no seu roteador atual), monitoramento automático de pastas e um moderno **Painel de Controle Web**.

---

## ⚡ Instalação Rápida no Proxmox VE (Comando Único)

Abra o **Shell do seu nó Proxmox VE (PVE)** e execute o comando abaixo:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/FelipeMzero/ProxPXE/main/proxmox/create-ct.sh)"
```

O assistente interativo:
1. Detecta automaticamente o próximo ID de Container disponível (ex: `110`).
2. Permite escolher o storage (`local-lvm`, `local-zfs`, etc.), memória RAM e rede (`vmbr0`).
3. **Compartilha suas ISOs do Proxmox:** Pergunta se você deseja montar `/var/lib/vz/template/iso` diretamente dentro do container, economizando espaço em disco!
4. Baixa o template oficial Debian 12, configura o bootloader GRUB2 Netboot e inicia todos os serviços do ProxPXE.
5. Ao finalizar, exibe o IP para você acessar o painel no navegador!

---

## 🌟 Principais Recursos do ProxPXE

- **Aplicação 100% em Shell Script (Bash):**
  - Zero dependências pesadas (sem Python, sem Node, sem Docker).
  - Consumo mínimo de memória RAM (< 150 MB para todo o container!).
  - Scripts modulares: `pxe-scan.sh`, `pxe-theme.sh`, `pxe-watch.sh` e `proxpxe` CLI.
- **Tela de Boot Estilo Ventoy:**
  - Baseada no motor gráfico `gfxmenu` do GRUB2 em alta resolução (1920x1080 Full HD).
  - Suporte completo a **UEFI (x86_64)** e **Legacy BIOS**.
  - Logotipo centralizado com a marca **ProxPXE**, papel de parede moderno, barra de contagem regressiva e atalhos de teclado.
- **Detecção Inteligente de Imagens ISO:**
  - Basta colocar qualquer arquivo `.iso` em `/data/iso/`.
  - O daemon em segundo plano detecta automaticamente o novo arquivo e **atualiza o menu de boot na hora**!
  - Reconhece: Proxmox VE, Windows 10/11/Server, Ubuntu, Debian, Clonezilla, Arch Linux e ISOs utilitárias.
  - Oferece modos rápidos: **HTTP Live Streaming**, **iPXE Sanboot** ou **Memdisk RAM**.
- **Modo Seguro ProxyDHCP (Porta 4011):**
  - O roteador da sua casa ou empresa continua distribuindo os IPs normalmente.
  - O servidor PXE responde **somente** quando um computador solicita inicialização por rede.
  - Zero risco de conflito de IP na sua rede local!
- **Painel de Controle Web Integrado:**
  - Visualize o status da rede, espaço em disco e ISOs cadastradas.
  - **Simulador Interativo da Tela Ventoy** em tempo real no navegador.
  - Botão de atualização rápida de menus.

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
