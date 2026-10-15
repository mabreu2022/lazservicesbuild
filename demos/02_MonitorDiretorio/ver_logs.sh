#!/bin/bash
echo "=== EXIBINDO ULTIMOS LOGS DO SERVICO SvcMonitorDiretorio (Ctrl+C para sair) ==="
journalctl -u SvcMonitorDiretorio -f -n 50
