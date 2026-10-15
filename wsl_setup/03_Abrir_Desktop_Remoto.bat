@echo off
chcp 65001 >nul
title Conectando ao Ubuntu Desktop na Unidade D:

echo ====================================================================
echo   INICIANDO DESKTOP REMOTO DO UBUNTU-D (localhost:3390)
echo ====================================================================
echo.

wsl.exe -d Ubuntu-D -u root service xrdp restart

echo.
echo Abrindo Conexao de Area de Trabalho Remota do Windows...
echo Use as credenciais:
echo   Usuario: developer
echo   Senha:   123456
echo.
start mstsc.exe /v:localhost:3390
