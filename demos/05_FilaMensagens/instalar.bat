@echo off
chcp 65001 >nul
title Instalador do Servico SvcFilaMensagens

:: Auto-elevacao de Administrador (UAC)
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ====================================================================
    echo Solicitando privilegios de Administrador para registro do servico...
    echo ====================================================================
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

cd /d "%~dp0"
set "BIN_PATH=%~dp0SvcFilaMensagens.exe"

if not exist "%BIN_PATH%" (
    echo [ERRO] O executavel "%BIN_PATH%" nao foi encontrado!
    echo Compile o projeto no Lazarus antes de executar este instalador.
    pause
    exit /b 1
)

echo [1/3] Registrando servico "SvcFilaMensagens" no Windows SCM...
sc.exe create "SvcFilaMensagens" binPath= "\"%BIN_PATH%\"" start= auto DisplayName= "Servico de Fila Continua de Mensagens" depend= Tcpip/LanmanWorkstation
if %errorLevel% neq 0 (
    echo [ERRO] Falha ao registrar o servico no SCM.
    pause
    exit /b %errorLevel%
)

echo [2/3] Configurando descricao do servico...
sc.exe description "SvcFilaMensagens" "Processamento continuo de tarefas via fila sincronizada com sinalizacao TEvent sem busy-wait."

echo [3/3] Iniciando o servico...
sc.exe start "SvcFilaMensagens"

echo ====================================================================
echo Servico "SvcFilaMensagens" instalado e iniciado com sucesso!
echo ====================================================================
pause
