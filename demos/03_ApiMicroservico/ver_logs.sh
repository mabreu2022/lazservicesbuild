#!/bin/bash
echo "=== EXIBINDO ULTIMOS LOGS DO SERVICO SvcApiMicroservico (Ctrl+C para sair) ==="
journalctl -u SvcApiMicroservico -f -n 50
