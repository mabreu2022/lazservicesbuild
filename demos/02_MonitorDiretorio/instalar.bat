@echo off
chcp 65001 >nul
title Instalador do Servico SvcMonitorDiretorio

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
set "BIN_PATH=%~dp0SvcMonitorDiretorio.exe"

if not exist "%BIN_PATH%" (
    echo [ERRO] O executavel "%BIN_PATH%" nao foi encontrado!
    echo Compile o projeto no Lazarus antes de executar este instalador.
    pause
    exit /b 1
)

echo [1/3] Registrando servico "SvcMonitorDiretorio" no Windows SCM...
sc.exe create "SvcMonitorDiretorio" binPath= "\"%BIN_PATH%\"" start= auto DisplayName= "Servico de Monitoramento de Arquivos e Pastas" depend= Tcpip/LanmanWorkstation
if %errorLevel% neq 0 (
    echo [ERRO] Falha ao registrar o servico no SCM.
    pause
    exit /b %errorLevel%
)

echo [2/3] Configurando descricao do servico...
sc.exe description "SvcMonitorDiretorio" "Varre pastas de entrada com teste de arquivos bloqueados e move para processados."

echo [3/3] Iniciando o servico...
sc.exe start "SvcMonitorDiretorio"

echo ====================================================================
echo Servico "SvcMonitorDiretorio" instalado e iniciado com sucesso!
echo ====================================================================
pause
