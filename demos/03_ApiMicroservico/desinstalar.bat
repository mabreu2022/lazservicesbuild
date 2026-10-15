@echo off
chcp 65001 >nul
title Desinstalador do Servico SvcApiMicroservico

:: Auto-elevacao de Administrador (UAC)
net session >nul 2>&1
if %errorLevel% neq 0 (
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

echo [1/2] Parando o servico "SvcApiMicroservico"...
sc.exe stop "SvcApiMicroservico"
timeout /t 3 /nobreak >nul

echo [2/2] Removendo o servico "SvcApiMicroservico" do sistema...
sc.exe delete "SvcApiMicroservico"

echo ====================================================================
echo Servico "SvcApiMicroservico" removido com sucesso!
echo ====================================================================
pause
