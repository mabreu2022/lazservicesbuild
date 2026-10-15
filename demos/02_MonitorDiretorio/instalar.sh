#!/bin/bash
# Script de Instalacao do Servico SvcMonitorDiretorio no Linux Systemd

if [ "$EUID" -ne 0 ]; then
  echo "Por favor, execute como root ou utilize: sudo $0"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_SOURCE="$SCRIPT_DIR/SvcMonitorDiretorio"
BIN_DEST="/usr/local/bin/SvcMonitorDiretorio"
SERVICE_FILE="/etc/systemd/system/SvcMonitorDiretorio.service"

if [ ! -f "$BIN_SOURCE" ]; then
  echo "[ERRO] Executavel $BIN_SOURCE nao encontrado! Compile no Lazarus primeiro."
  exit 1
fi

echo "[1/4] Copiando binario para $BIN_DEST..."
cp "$BIN_SOURCE" "$BIN_DEST"
chmod +x "$BIN_DEST"

echo "[2/4] Instalando arquivo de servico em $SERVICE_FILE..."
cp "$SCRIPT_DIR/SvcMonitorDiretorio.service" "$SERVICE_FILE"

echo "[3/4] Recarregando Systemd..."
systemctl daemon-reload

echo "[4/4] Habilitando e iniciando servico SvcMonitorDiretorio..."
systemctl enable SvcMonitorDiretorio
systemctl start SvcMonitorDiretorio

echo "====================================================================="
echo "Servico SvcMonitorDiretorio instalado e ativo com sucesso no Linux!"
echo "Verifique o status com: systemctl status SvcMonitorDiretorio"
echo "====================================================================="
