#!/bin/bash
# Script de Remocao do Servico SvcApiMicroservico

if [ "$EUID" -ne 0 ]; then
  echo "Por favor, execute como root ou utilize: sudo $0"
  exit 1
fi

echo "[1/4] Parando servico SvcApiMicroservico..."
systemctl stop SvcApiMicroservico 2>/dev/null

echo "[2/4] Desabilitando servico do boot..."
systemctl disable SvcApiMicroservico 2>/dev/null

echo "[3/4] Removendo arquivo de servico..."
rm -f "/etc/systemd/system/SvcApiMicroservico.service"
systemctl daemon-reload

echo "[4/4] Removendo binario de /usr/local/bin/SvcApiMicroservico..."
rm -f "/usr/local/bin/SvcApiMicroservico"

echo "====================================================================="
echo "Servico SvcApiMicroservico removido com sucesso!"
echo "====================================================================="
