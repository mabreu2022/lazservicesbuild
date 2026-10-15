#!/bin/bash
# Script de Remocao do Servico SvcFilaMensagens

if [ "$EUID" -ne 0 ]; then
  echo "Por favor, execute como root ou utilize: sudo $0"
  exit 1
fi

echo "[1/4] Parando servico SvcFilaMensagens..."
systemctl stop SvcFilaMensagens 2>/dev/null

echo "[2/4] Desabilitando servico do boot..."
systemctl disable SvcFilaMensagens 2>/dev/null

echo "[3/4] Removendo arquivo de servico..."
rm -f "/etc/systemd/system/SvcFilaMensagens.service"
systemctl daemon-reload

echo "[4/4] Removendo binario de /usr/local/bin/SvcFilaMensagens..."
rm -f "/usr/local/bin/SvcFilaMensagens"

echo "====================================================================="
echo "Servico SvcFilaMensagens removido com sucesso!"
echo "====================================================================="
