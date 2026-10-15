#!/bin/bash
# Script de Remocao do Servico SvcPoolBancoDados

if [ "$EUID" -ne 0 ]; then
  echo "Por favor, execute como root ou utilize: sudo $0"
  exit 1
fi

echo "[1/4] Parando servico SvcPoolBancoDados..."
systemctl stop SvcPoolBancoDados 2>/dev/null

echo "[2/4] Desabilitando servico do boot..."
systemctl disable SvcPoolBancoDados 2>/dev/null

echo "[3/4] Removendo arquivo de servico..."
rm -f "/etc/systemd/system/SvcPoolBancoDados.service"
systemctl daemon-reload

echo "[4/4] Removendo binario de /usr/local/bin/SvcPoolBancoDados..."
rm -f "/usr/local/bin/SvcPoolBancoDados"

echo "====================================================================="
echo "Servico SvcPoolBancoDados removido com sucesso!"
echo "====================================================================="
