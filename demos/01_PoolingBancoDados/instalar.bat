@echo off
chcp 65001 >nul
title Instalador do Servico SvcPoolBancoDados

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
set "BIN_PATH=%~dp0SvcPoolBancoDados.exe"

if not exist "%BIN_PATH%" (
    echo [ERRO] O executavel "%BIN_PATH%" nao foi encontrado!
    echo Compile o projeto no Lazarus antes de executar este instalador.
    pause
    exit /b 1
)

echo [1/3] Registrando servico "SvcPoolBancoDados" no Windows SCM...
sc.exe create "SvcPoolBancoDados" binPath= "\"%BIN_PATH%\"" start= auto DisplayName= "Servico de Pooling e Monitoramento de Banco de Dados" depend= Tcpip/LanmanWorkstation/FirebirdServerDefaultInstance
if %errorLevel% neq 0 (
    echo [ERRO] Falha ao registrar o servico no SCM.
    pause
    exit /b %errorLevel%
)

echo [2/3] Configurando descricao do servico...
sc.exe description "SvcPoolBancoDados" "Verifica periodicamente tabelas de filas e registros pendentes em banco de dados."

echo [3/3] Iniciando o servico...
sc.exe start "SvcPoolBancoDados"

echo ====================================================================
echo Servico "SvcPoolBancoDados" instalado e iniciado com sucesso!
echo ====================================================================
pause
