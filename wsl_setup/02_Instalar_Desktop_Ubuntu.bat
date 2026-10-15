@echo off
chcp 65001 >nul
title Instalando Ambiente Desktop XFCE e XRDP no Ubuntu-D

echo ====================================================================
echo   INSTALACAO DO AMBIENTE GRAFICO (DESKTOP) NO UBUNTU-D
echo ====================================================================
echo.

wsl.exe --list | findstr /i "Ubuntu-D" >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERRO] A distribuicao Ubuntu-D ainda nao foi instalada.
    echo Execute primeiro o script: 01_Instalar_Ubuntu_Unidade_D.bat
    pause
    exit /b 1
)

echo [1/3] Atualizando repositorios e instalando XFCE4 e XRDP...
echo (Este processo pode levar alguns minutos dependendo da sua conexao)
wsl.exe -d Ubuntu-D -u root sh -c "apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y xfce4 xfce4-goodies xrdp dbus-x11"

echo.
echo [2/3] Configurando porta do XRDP para 3390 (evitando conflito com o Windows)...
wsl.exe -d Ubuntu-D -u root sh -c "sed -i 's/port=3389/port=3390/g' /etc/xrdp/xrdp.ini"
wsl.exe -d Ubuntu-D -u root sh -c "echo 'xfce4-session' > /etc/skel/.xsession"
wsl.exe -d Ubuntu-D -u root sh -c "echo 'xfce4-session' > /root/.xsession"

echo.
echo [3/3] Criando usuario padrao 'developer' (senha: 123456)...
wsl.exe -d Ubuntu-D -u root sh -c "id -u developer >/dev/null 2>&1 || useradd -m -s /bin/bash developer && echo 'developer:123456' | chpasswd && usermod -aG sudo developer && echo 'xfce4-session' > /home/developer/.xsession && chown developer:developer /home/developer/.xsession"

echo.
echo ====================================================================
echo   DESKTOP INSTALADO COM SUCESSO!
echo ====================================================================
echo.
echo Para abrir a interface grafica completa no Windows, execute:
echo   03_Abrir_Desktop_Remoto.bat
echo.
echo Credenciais de Login:
echo   Usuario: developer
echo   Senha:   123456
echo.
pause
