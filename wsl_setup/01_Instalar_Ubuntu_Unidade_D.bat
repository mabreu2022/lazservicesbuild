@echo off
chcp 65001 >nul
title Instalador do WSL Ubuntu na Unidade D:

:: 1. Auto-elevação de Administrador (UAC)
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ====================================================================
    echo Solicitando privilegios de Administrador para configurar o WSL...
    echo ====================================================================
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

echo ====================================================================
echo   INSTALACAO DO WSL UBUNTU HOSPEDADO NA UNIDADE D:
echo ====================================================================
echo.

:: 2. Habilita recursos necessários no Windows
echo [1/6] Habilitando recursos do Windows (Subsystem Linux e Plataforma VM)...
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart

:: 3. Atualiza o kernel do WSL
echo.
echo [2/6] Atualizando componentes do kernel WSL...
wsl.exe --update

:: 4. Cria pastas na unidade D
echo.
echo [3/6] Criando pasta de destino D:\WSL\Ubuntu...
if not exist "D:\WSL" mkdir "D:\WSL"
if not exist "D:\WSL\Ubuntu" mkdir "D:\WSL\Ubuntu"

:: 5. Download da imagem oficial do Ubuntu 24.04 LTS (~370 MB)
set "IMG_PATH=D:\WSL\noble-wsl-amd64.wsl"
if exist "%IMG_PATH%" (
    echo [4/6] Imagem oficial do Ubuntu encontrada em "%IMG_PATH%".
) else (
    echo [4/6] Baixando imagem oficial do Ubuntu 24.04 LTS (~370 MB) para D:\WSL...
    curl.exe -L -# -o "%IMG_PATH%" "https://cdimages.ubuntu.com/ubuntu-wsl/noble/daily-live/current/noble-wsl-amd64.wsl"
    if %errorLevel% neq 0 (
        echo [ERRO] Falha ao baixar a imagem do Ubuntu. Verifique sua conexao com a internet.
        pause
        exit /b 1
    )
)

:: 6. Importa para o WSL diretamente na unidade D (o disco ext4.vhdx ficara em D:\WSL\Ubuntu)
echo.
echo [5/6] Importando distribuicao Ubuntu-D para D:\WSL\Ubuntu...
wsl.exe --list | findstr /i "Ubuntu-D" >nul 2>&1
if %errorLevel% equ 0 (
    echo A distribuicao Ubuntu-D ja esta registrada no WSL.
) else (
    wsl.exe --import Ubuntu-D "D:\WSL\Ubuntu" "%IMG_PATH%" --version 2
    if %errorLevel% neq 0 (
        echo [AVISO] Falha ao importar como WSL2. Tentando importar como WSL1...
        wsl.exe --import Ubuntu-D "D:\WSL\Ubuntu" "%IMG_PATH%" --version 1
    )
)

:: 7. Configura Systemd e utilitarios essenciais no Ubuntu
echo.
echo [6/6] Configurando suporte a Systemd e instalando Free Pascal / utilitarios...
wsl.exe -d Ubuntu-D -u root sh -c "printf '[boot]\nsystemd=true\n' > /etc/wsl.conf"
wsl.exe -d Ubuntu-D -u root sh -c "apt-get update && apt-get install -y fpc sudo curl nano systemd"

echo.
echo ====================================================================
echo   UBUNTU INSTALADO COM SUCESSO NA UNIDADE D: (D:\WSL\Ubuntu)
echo ====================================================================
echo.
echo Para abrir o terminal do Linux, execute: 04_Abrir_Terminal_Ubuntu.bat
echo Para instalar o ambiente Desktop (Interface Grafica), execute: 02_Instalar_Desktop_Ubuntu.bat
echo.
pause
