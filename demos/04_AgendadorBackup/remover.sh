#!/bin/bash
# Script de Remocao do Servico SvcAgendadorBackup

if [ "$EUID" -ne 0 ]; then
  echo "Por favor, execute como root ou utilize: sudo $0"
  exit 1
fi

echo "[1/4] Parando servico SvcAgendadorBackup..."
systemctl stop SvcAgendadorBackup 2>/dev/null

echo "[2/4] Desabilitando servico do boot..."
systemctl disable SvcAgendadorBackup 2>/dev/null

echo "[3/4] Removendo arquivo de servico..."
rm -f "/etc/systemd/system/SvcAgendadorBackup.service"
systemctl daemon-reload

echo "[4/4] Removendo binario de /usr/local/bin/SvcAgendadorBackup..."
rm -f "/usr/local/bin/SvcAgendadorBackup"

echo "====================================================================="
echo "Servico SvcAgendadorBackup removido com sucesso!"
echo "====================================================================="
