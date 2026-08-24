#!/usr/bin/env bash
# =============================================================================
# PSI512 - Trabalho Avaliativo 1 - Implantacao A (Minikube)
# Teste de estresse e medicao do HPA.
#
# Este script e um invocador fino: toda a logica de coleta esta em
# ../common/hpa-test.sh, compartilhada com a Implantacao B. E deliberado -
# medir os dois ambientes com o mesmo codigo e o que garante que as diferencas
# observadas venham do ambiente, e nao do roteiro de coleta.
#
# Substitui o minikube-load-test.sh da raiz do repositorio, que nao registra
# horarios (impedindo o calculo do tempo de reacao do HPA exigido pelo
# enunciado) e encerra antes do scale-down.
#
# Pre-requisito: aplicacao ja implantada (./deploy-minikube.sh na raiz).
#
# Uso:
#   ./20-load-test.sh                 # 60s repouso, 300s carga, 420s recuperacao
#   ./20-load-test.sh 60 300 420 3    # com 3 geradores concorrentes
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")"

export AMBIENTE="minikube"
export MANIFEST_GEN="./12-load-generator.yaml"
# Cada aluno grava na sua propria pasta: o enunciado exige execucao e
# validacao individuais, e sem o nome no caminho nao ha como atribuir uma
# execucao a quem a fez. ALUNO cai no usuario do sistema se nao for informado.
export EVID_DIR="${EVID_DIR:-$(pwd)/evidencias/${ALUNO:-$(id -un)}}"
export HPA_NAME="python-web-hpa"
export APP_LABEL="app=python-web"

# Verificacao previa: sem metrics-server o HPA reporta <unknown> e o teste
# inteiro produz uma coluna de "NA". Melhor falhar aqui, com mensagem clara.
if ! kubectl top nodes >/dev/null 2>&1; then
  echo "ERRO: metrics-server indisponivel. Rode: minikube addons enable metrics-server"
  exit 1
fi

exec ../common/hpa-test.sh "$@"
