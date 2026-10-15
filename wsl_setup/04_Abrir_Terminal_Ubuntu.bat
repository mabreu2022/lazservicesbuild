@echo off
chcp 65001 >nul
title Terminal Ubuntu-D (Unidade D:)

echo Abrindo Terminal Bash no Ubuntu-D...
wsl.exe -d Ubuntu-D --cd "%~dp0.."
