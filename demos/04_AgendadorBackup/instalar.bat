@echo off
chcp 65001 >nul
title Instalador do Servico SvcAgendadorBackup

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
set "BIN_PATH=%~dp0SvcAgendadorBackup.exe"

if not exist "%BIN_PATH%" (
    echo [ERRO] O executavel "%BIN_PATH%" nao foi encontrado!
    echo Compile o projeto no Lazarus antes de executar este instalador.
    pause
    exit /b 1
)

echo [1/3] Registrando servico "SvcAgendadorBackup" no Windows SCM...
sc.exe create "SvcAgendadorBackup" binPath= "\"%BIN_PATH%\"" start= auto DisplayName= "Servico de Agendamento Diario e Backup" depend= Tcpip/LanmanWorkstation
if %errorLevel% neq 0 (
    echo [ERRO] Falha ao registrar o servico no SCM.
    pause
    exit /b %errorLevel%
)

echo [2/3] Configurando descricao do servico...
sc.exe description "SvcAgendadorBackup" "Disparo automatico em horario diario fixo para rotinas de backup e manutencao."

echo [3/3] Iniciando o servico...
sc.exe start "SvcAgendadorBackup"

echo ====================================================================
echo Servico "SvcAgendadorBackup" instalado e iniciado com sucesso!
echo ====================================================================
pause
