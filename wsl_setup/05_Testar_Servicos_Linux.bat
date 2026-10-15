@echo off
chcp 65001 >nul
title Testador de Servicos Linux via WSL (Ubuntu-D)

echo ====================================================================
echo   TESTE DE SERVICOS LINUX NO UBUNTU-D (SYSTEMD NATIVO)
echo ====================================================================
echo.
echo Escolha o servico que deseja testar no Linux:
echo [1] Demo 01 - Pooling de Banco de Dados (SvcPoolBancoDados)
echo [2] Demo 02 - Monitor de Diretorio (SvcMonitorDiretorio)
echo [3] Demo 03 - API / Microservico (SvcApiMicroservico)
echo [4] Demo 04 - Agendador de Backup (SvcAgendadorBackup)
echo [5] Demo 05 - Fila de Mensagens (SvcFilaMensagens)
echo.
set /p OPC="Digite o numero da opcao (1-5): "

set "DEMO_FOLDER="
set "SVC_NAME="

if "%OPC%"=="1" (
    set "DEMO_FOLDER=demos/01_PoolingBancoDados"
    set "SVC_NAME=SvcPoolBancoDados"
)
if "%OPC%"=="2" (
    set "DEMO_FOLDER=demos/02_MonitorDiretorio"
    set "SVC_NAME=SvcMonitorDiretorio"
)
if "%OPC%"=="3" (
    set "DEMO_FOLDER=demos/03_ApiMicroservico"
    set "SVC_NAME=SvcApiMicroservico"
)
if "%OPC%"=="4" (
    set "DEMO_FOLDER=demos/04_AgendadorBackup"
    set "SVC_NAME=SvcAgendadorBackup"
)
if "%OPC%"=="5" (
    set "DEMO_FOLDER=demos/05_FilaMensagens"
    set "SVC_NAME=SvcFilaMensagens"
)

if "%DEMO_FOLDER%"=="" (
    echo Opcao invalida.
    pause
    exit /b 1
)

echo.
echo ====================================================================
echo Compilando %SVC_NAME% nativamente para Linux dentro do Ubuntu-D...
echo ====================================================================
wsl.exe -d Ubuntu-D -u root sh -c "cd '/mnt/d/Fontes Lazarus/Fabrica de Seriços/Lazarus/%DEMO_FOLDER%' && fpc -Mobjfpc -Sh %SVC_NAME%.lpr"

echo.
echo ====================================================================
echo Executando %SVC_NAME% no modo interativo (--debug) dentro do Linux...
echo (Pressione Ctrl+C para encerrar o teste limpo)
echo ====================================================================
wsl.exe -d Ubuntu-D -u root sh -c "cd '/mnt/d/Fontes Lazarus/Fabrica de Seriços/Lazarus/%DEMO_FOLDER%' && ./%SVC_NAME% --debug"

pause
