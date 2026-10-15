# Fábrica de Serviços Cross-Platform (Windows & Linux)
### Wizard de Produção RAD para Lazarus & Free Pascal

Um gerador de projetos visual em **Lazarus (Free Pascal)** desenvolvido no formato de **Wizard de Produção com TPageControl** (abas ocultas, navegação por Voltar/Avançar/Concluir), eliminando todas as complexidades de infraestrutura para o desenvolvedor e gerando serviços profissionais e desacoplados para **Windows (SCM)** e **Linux (Systemd)**.

---

## 🌟 Principais Recursos

### 1. Modo Dual: Serviço Invisível + Console Interativo de Debug
Todo código gerado suporta nativamente o parâmetro `/debug` (Windows) ou `-d` / `--debug` (Linux):
- **SCM / Systemd:** Execução 100% silenciosa, sem interface e sem consumo de recursos gráficos.
- **Terminal Manual:** Inicia um console interativo com banner informativo, timestamps com milissegundos, níveis de severidade (`[DEBUG]`, `[INFO]`, `[WARN]`, `[ERROR]`), e encerramento limpo via **Ctrl+C** (com desativação graciosa de threads sem leak de memória).

### 2. Gerenciador Automático de Arquivo de Configuração (.ini)
- Inclui uma unit `uConfig.pas` baseada em Singleton thread-safe (`TAppConfig.Instance`).
- Cria automaticamente o arquivo `<NomeServico>.ini` com documentação e seções adequadas ao arquétipo escolhido caso ele ainda não exista.
- **SIGHUP no Linux:** Suporte a recarregamento a quente (*hot-reload*) de parâmetros sem reiniciar o daemon ao receber o sinal `SIGHUP` (`kill -HUP <PID>` ou `systemctl reload`).

### 3. Orquestração de Dependências de Inicialização
- **Windows (SCM):** Injeta dependências automáticas de rede e banco de dados via `sc.exe create ... depend= Tcpip/LanmanWorkstation/FirebirdServerDefaultInstance`.
- **Linux (Systemd):** Injeta diretivas no arquivo `.service` (`After=network.target network-online.target firebird.service`, `Wants=network-online.target`).

### 4. Scripts de Instalação com Auto-Elevação UAC (Windows) e Root Check (Linux)
- **Windows:**
  - `instalar.bat`: Detecta automaticamente privilégios administrativos; caso não esteja elevado, solicita elevação via UAC (`powershell -Command "Start-Process '%~f0' -Verb RunAs"`), cria o serviço no SCM, configura a descrição e inicia o serviço.
  - `desinstalar.bat`: Auto-elevação UAC, para o serviço e o remove com segurança via `sc.exe delete`.
- **Linux:**
  - `instalar.sh`: Valida `root`/`sudo`, copia o binário para `/usr/local/bin`, instala o `.service` em `/etc/systemd/system/`, executa `daemon-reload`, habilita no boot e inicia.
  - `remover.sh`: Para, desabilita e remove a unit do systemd.
  - `status.sh`: Exibe o estado operacional atual do serviço (`systemctl status`).
  - `ver_logs.sh`: Monitora os logs em tempo real (`journalctl -u <servico> -f -n 50`).

### 5. Zero Dependência Visual (LCL) nos Serviços Gerados
O aplicativo do Wizard utiliza **Lazarus LCL** para a interface do desenvolvedor, mas **todo o serviço final gerado compila puramente em FCL/RTL** (executável ultra-leve de ~240 KB, sem DLLs de interface gráfica nem overhead de memória).

---

## 🎯 Arquétipos Especializados de Tarefa

O Wizard disponibiliza 5 arquétipos de produção prontos para uso:

| Arquétipo | Descrição e Comportamento |
| :--- | :--- |
| **Consulta / Pooling de BD** | Thread com loop de reconexão e tratamento de exceção para consultas periódicas em banco de dados (Firebird, PostgreSQL, MySQL, etc.). |
| **Monitor de Pastas** | Varredura de diretório de entrada (*inbox*), teste de arquivos bloqueados/em cópia (`FileOpen` com `fmShareExclusive`) e movimentação segura para *outbox*/*error*. |
| **API / Microserviço** | Esqueleto de listener TCP/HTTP em porta configurável, inicializando sockets no `Start` e liberando-os no `Stop`. |
| **Agendador / Backup** | Execução diária em horário fixo (ex: `02:00:00`), calculando precisão de tempo restante sem travamentos. |
| **Fila de Tarefas Contínua** | Consumidor contínuo apoiado em `TEvent` sem espera ocupada (*zero busy-wait*). |

---

## 📁 Estrutura de Fontes do Wizard

```
d:\Fontes Lazarus\Fabrica de Seriços\Lazarus\
├── FabricaServicos.lpi     <- Projeto do Wizard para abrir no Lazarus IDE
├── FabricaServicos.lpr     <- Ponto de entrada do aplicativo Wizard
├── uMainWizard.pas         <- Formulário principal com fluxo de 5 etapas
├── uMainWizard.lfm         <- Layout visual do Wizard
├── uTemplateEngine.pas     <- Motor gerador de templates cross-platform
└── ProjetosGerados\        <- Pasta padrão onde os serviços gerados são salvos
    └── SyncVendasSvc\
        ├── SyncVendasSvc.lpi
        ├── SyncVendasSvc.lpr
        ├── uServiceCore.pas
        ├── uWorker.pas
        ├── uConfig.pas
        ├── SyncVendasSvc.ini
        ├── SyncVendasSvc.service
        ├── instalar.bat
        ├── desinstalar.bat
        ├── instalar.sh
        ├── remover.sh
        ├── status.sh
        └── ver_logs.sh
```

---

## 🚀 Como Executar o Wizard no Lazarus

1. Abra o **Lazarus IDE**.
2. Clique no menu **Projeto -> Abrir Projeto...**
3. Selecione o arquivo `d:\Fontes Lazarus\Fabrica de Seriços\Lazarus\FabricaServicos.lpi`.
4. Pressione **F9** (ou clique no botão verde *Executar*).
5. Siga o assistente de 5 etapas:
   - **Etapa 1:** Defina o nome do serviço, descrição e plataforma (Híbrido, Windows ou Linux).
   - **Etapa 2:** Selecione o arquétipo da tarefa (Banco de dados, Monitor de pastas, API, etc.).
   - **Etapa 3:** Configure a frequência do loop e ative o leitor automático de `.ini`.
   - **Etapa 4:** Defina parâmetros de recuperação de falhas (`Restart=always`), usuário Linux e dependências.
   - **Etapa 5:** Confira o resumo, pré-visualize o código e clique em **[Gerar e Abrir Pasta]**.

---

## 🛠️ Como Testar o Serviço Gerado sem Instalar

Entre na pasta do projeto gerado e execute diretamente no terminal:
```bash
# No Windows (Prompt de comando ou PowerShell):
SyncVendasSvc.exe /debug

# No Linux (Bash):
./SyncVendasSvc --debug
```
Para encerrar a execução de teste com segurança, basta pressionar **Ctrl+C**. O serviço finaliza a thread de trabalho, libera os recursos e encerra sem erros.
