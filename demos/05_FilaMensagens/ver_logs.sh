#!/bin/bash
echo "=== EXIBINDO ULTIMOS LOGS DO SERVICO SvcFilaMensagens (Ctrl+C para sair) ==="
journalctl -u SvcFilaMensagens -f -n 50
