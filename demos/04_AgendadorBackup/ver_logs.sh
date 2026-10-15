#!/bin/bash
echo "=== EXIBINDO ULTIMOS LOGS DO SERVICO SvcAgendadorBackup (Ctrl+C para sair) ==="
journalctl -u SvcAgendadorBackup -f -n 50
