#!/bin/bash
# Script de Instalacao do Servico SvcFilaMensagens no Linux Systemd

if [ "$EUID" -ne 0 ]; then
  echo "Por favor, execute como root ou utilize: sudo $0"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_SOURCE="$SCRIPT_DIR/SvcFilaMensagens"
BIN_DEST="/usr/local/bin/SvcFilaMensagens"
SERVICE_FILE="/etc/systemd/system/SvcFilaMensagens.service"

if [ ! -f "$BIN_SOURCE" ]; then
  echo "[ERRO] Executavel $BIN_SOURCE nao encontrado! Compile no Lazarus primeiro."
  exit 1
fi

echo "[1/4] Copiando binario para $BIN_DEST..."
cp "$BIN_SOURCE" "$BIN_DEST"
chmod +x "$BIN_DEST"

echo "[2/4] Instalando arquivo de servico em $SERVICE_FILE..."
cp "$SCRIPT_DIR/SvcFilaMensagens.service" "$SERVICE_FILE"

echo "[3/4] Recarregando Systemd..."
systemctl daemon-reload

echo "[4/4] Habilitando e iniciando servico SvcFilaMensagens..."
systemctl enable SvcFilaMensagens
systemctl start SvcFilaMensagens

echo "====================================================================="
echo "Servico SvcFilaMensagens instalado e ativo com sucesso no Linux!"
echo "Verifique o status com: systemctl status SvcFilaMensagens"
echo "====================================================================="
