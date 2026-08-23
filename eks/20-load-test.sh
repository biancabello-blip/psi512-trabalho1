#!/usr/bin/env bash
# =============================================================================
# PSI512 - Trabalho Avaliativo 1 - Implantacao B (AWS EKS)
# Teste de estresse e medicao do HPA.
#
# Invocador fino: a logica de coleta esta em ../common/hpa-test.sh, o mesmo
# arquivo usado pela Implantacao A. Ver os comentarios de metodologia la.
#
# Pre-requisitos: ./03-deploy-app.sh concluido e metrics-server instalado
# (./02-metrics-server.sh).
#
# Uso:
#   ./20-load-test.sh                 # 60s repouso, 300s carga, 420s recuperacao
#   ./20-load-test.sh 60 300 420 3    # com 3 geradores concorrentes
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")"
source ./00-config.sh

export AMBIENTE="eks"
export MANIFEST_GEN="./12-load-generator.yaml"
export EVID_DIR
export HPA_NAME="python-web-hpa"
export APP_LABEL="app=python-web"

if ! kubectl top nodes >/dev/null 2>&1; then
  echo "ERRO: metrics-server indisponivel. Rode: ./02-metrics-server.sh"
  exit 1
fi

exec ../common/hpa-test.sh "$@"
