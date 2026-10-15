@echo off
chcp 65001 >nul
title Desinstalador do Servico SvcMonitorDiretorio

:: Auto-elevacao de Administrador (UAC)
net session >nul 2>&1
if %errorLevel% neq 0 (
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

echo [1/2] Parando o servico "SvcMonitorDiretorio"...
sc.exe stop "SvcMonitorDiretorio"
timeout /t 3 /nobreak >nul

echo [2/2] Removendo o servico "SvcMonitorDiretorio" do sistema...
sc.exe delete "SvcMonitorDiretorio"

echo ====================================================================
echo Servico "SvcMonitorDiretorio" removido com sucesso!
echo ====================================================================
pause
