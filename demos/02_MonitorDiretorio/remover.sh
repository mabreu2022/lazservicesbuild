#!/bin/bash
# Script de Remocao do Servico SvcMonitorDiretorio

if [ "$EUID" -ne 0 ]; then
  echo "Por favor, execute como root ou utilize: sudo $0"
  exit 1
fi

echo "[1/4] Parando servico SvcMonitorDiretorio..."
systemctl stop SvcMonitorDiretorio 2>/dev/null

echo "[2/4] Desabilitando servico do boot..."
systemctl disable SvcMonitorDiretorio 2>/dev/null

echo "[3/4] Removendo arquivo de servico..."
rm -f "/etc/systemd/system/SvcMonitorDiretorio.service"
systemctl daemon-reload

echo "[4/4] Removendo binario de /usr/local/bin/SvcMonitorDiretorio..."
rm -f "/usr/local/bin/SvcMonitorDiretorio"

echo "====================================================================="
echo "Servico SvcMonitorDiretorio removido com sucesso!"
echo "====================================================================="
