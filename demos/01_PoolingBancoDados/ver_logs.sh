#!/bin/bash
echo "=== EXIBINDO ULTIMOS LOGS DO SERVICO SvcPoolBancoDados (Ctrl+C para sair) ==="
journalctl -u SvcPoolBancoDados -f -n 50
