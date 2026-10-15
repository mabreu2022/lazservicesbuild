# Demos dos 5 Arquétipos de Serviços (Windows & Linux)

Esta pasta contém **5 projetos de serviços completos, compilados e testados**, cada um implementando um arquétipo de produção específico gerado pela **Fábrica de Serviços Cross-Platform**.

---

## 📂 Visão Geral dos Demos

| Pasta | Nome do Serviço | Arquétipo | Finalidade |
| :--- | :--- | :--- | :--- |
| `01_PoolingBancoDados` | `SvcPoolBancoDados` | **Pooling de BD** | Conexão periódica, tratamento de reconexão e consulta de tabelas de filas/registros. |
| `02_MonitorDiretorio` | `SvcMonitorDiretorio` | **Monitor de Pastas** | Varredura de pasta `inbox`, teste de bloqueio de arquivo (`IsFileLocked`) e movimentação segura. |
| `03_ApiMicroservico` | `SvcApiMicroservico` | **API / Microserviço** | Listener TCP/HTTP em porta configurável com ciclo de vida limpo no Start/Stop. |
| `04_AgendadorBackup` | `SvcAgendadorBackup` | **Agendador Diário** | Disparo diário pontual em horário fixo (ex: `02:00:00`) com prevenção contra repetições. |
| `05_FilaMensagens` | `SvcFilaMensagens` | **Fila de Tarefas** | Consumidor contínuo apoiado em `TEvent` sem consumo ocioso de CPU (*zero busy-wait*). |

---

## 🧪 Como Testar Imediatamente Qualquer Demo (Modo Debug)

Cada pasta já contém o executável `.exe` compilado e pronto para teste no terminal sem precisar registrar no Windows SCM:

```bash
# Exemplo: Testando o Monitor de Diretório
cd "d:\Fontes Lazarus\Fabrica de Seriços\Lazarus\demos\02_MonitorDiretorio"
.\SvcMonitorDiretorio.exe /debug

# Exemplo: Testando o Pooling de Banco de Dados
cd "d:\Fontes Lazarus\Fabrica de Seriços\Lazarus\demos\01_PoolingBancoDados"
.\SvcPoolBancoDados.exe /debug
```

Para encerrar a execução do teste, basta pressionar **Ctrl+C**. O serviço interrompe a thread com segurança e encerra com 0 vazamentos de memória.

---

## 🪟 Instalação no Windows

Dê um duplo clique no arquivo `instalar.bat` dentro da pasta do demo desejado. Ele detectará privilégios e solicitará permissão administrativa (UAC) automaticamente, registrando e iniciando o serviço no Windows SCM.

Para remover, dê um duplo clique em `desinstalar.bat`.

---

## 🐧 Instalação no Linux (Systemd)

Copie a pasta para sua máquina Linux (ou WSL):
```bash
sudo ./instalar.sh
```
Para verificar o status:
```bash
./status.sh
```
Para ver os logs em tempo real:
```bash
./ver_logs.sh
```
