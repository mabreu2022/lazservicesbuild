# Configuração do WSL Ubuntu Desktop Hospedado na Unidade D:

Este diretório contém os scripts automatizados para instalar e rodar uma distribuição **Ubuntu 24.04 LTS com Interface Gráfica (Desktop XFCE + XRDP)** e **suporte nativo a Systemd**, com o disco virtual (`ext4.vhdx`) hospedado **100% na sua unidade D:** (`D:\WSL\Ubuntu`).

---

## 🚀 Passo a Passo de Instalação e Uso

### Passo 1: Instalar o Ubuntu na Unidade D:
Execute com duplo clique o script:
👉 **`01_Instalar_Ubuntu_Unidade_D.bat`**

O que ele faz automaticamente:
1. Detecta permissões e solicita elevação de Administrador (UAC).
2. Habilita os recursos necessários do Windows: *Subsistema do Windows para Linux* e *Plataforma de Máquina Virtual*.
3. Cria a pasta `D:\WSL\Ubuntu`.
4. Baixa a imagem oficial do Ubuntu 24.04 LTS (~370 MB) direto da Canonical para `D:\WSL`.
5. Importa a distribuição para o WSL com o nome **`Ubuntu-D`**, salvando o disco virtual em **`D:\WSL\Ubuntu\ext4.vhdx`**.
6. Habilita o **Systemd nativo** (`/etc/wsl.conf`) e instala o Free Pascal (`fpc`).

> **Nota:** Se a sua máquina ainda não tinha os recursos do Windows habilitados no Windows Features, o instalador solicitará reiniciar o computador uma única vez para carregar o hipervisor do WSL2.

---

### Passo 2: Instalar a Interface Gráfica (Desktop)
Execute com duplo clique o script:
👉 **`02_Instalar_Desktop_Ubuntu.bat`**

O que ele faz:
1. Instala o ambiente desktop leve **XFCE4** e o servidor **XRDP**.
2. Configura a porta do XRDP para **`3390`** (para nunca entrar em conflito com a porta padrão 3389 do Windows).
3. Cria o usuário padrão:
   - **Usuário:** `developer`
   - **Senha:** `123456`

---

### Passo 3: Abrir o Desktop do Linux no Windows
Execute com duplo clique o script:
👉 **`03_Abrir_Desktop_Remoto.bat`**

Ele iniciará o serviço XRDP no Ubuntu e abrirá a **Conexão de Área de Trabalho Remota (`mstsc.exe`)** do Windows conectando direto no Ubuntu na unidade D!
Basta fazer o login com `developer` / `123456`.

---

### Passo 4: Abrir o Terminal ou Testar os Serviços
- **Para abrir o terminal Bash no Ubuntu:** Dê duplo clique em **`04_Abrir_Terminal_Ubuntu.bat`**.
- **Para compilar e testar os serviços no Linux:** Dê duplo clique em **`05_Testar_Servicos_Linux.bat`**, escolha o número do demo (1 a 5) e ele compilará com o `fpc` nativo do Linux e executará no modo interativo (`--debug`).
