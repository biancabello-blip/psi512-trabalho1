#!/usr/bin/env bash
# =============================================================================
# PSI512 - Trabalho Avaliativo 1 - Implantacao B (AWS EKS)
# Etapa 2: instalar o metrics-server.
#
# ESTE E O PONTO EM QUE O EKS MAIS DIFERE DO MINIKUBE.
#
# O HPA nao mede CPU por conta propria: ele consulta a API metrics.k8s.io, que
# so existe se houver um servidor de metricas registrado como APIService. No
# Minikube isso e um addon de uma linha ("minikube addons enable
# metrics-server"). No EKS o componente NAO vem instalado e nao ha addon
# gerenciado equivalente: e preciso aplicar o manifesto oficial do projeto
# metrics-server, exatamente como indica a documentacao da AWS citada no
# enunciado.
#
# Sem esta etapa o HPA fica indefinidamente em "cpu: <unknown>/10%" e nunca
# escala - sintoma que vale registrar como evidencia negativa no artigo.
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")"
source ./00-config.sh
mkdir -p "${EVID_DIR}"

echo "== EVIDENCIA: estado ANTES da instalacao (deve falhar)"
# "|| true" porque o comando retorna erro quando a API de metricas nao existe;
# esse erro e justamente a evidencia que se quer registrar.
kubectl top nodes 2>&1 | tee "${EVID_DIR}/E2-top-antes.txt" || true

echo
echo "== Instalando o metrics-server"
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

echo
echo "== Aguardando o Deployment ficar disponivel"
kubectl -n kube-system rollout status deployment/metrics-server --timeout=180s

# O metrics-server leva mais alguns segundos para coletar a primeira janela de
# amostras depois de ficar Ready. Sem esta espera o "kubectl top" ainda
# retornaria erro.
echo "== Aguardando a primeira coleta de metricas (30s)"
sleep 30

echo
echo "== EVIDENCIA: estado DEPOIS da instalacao"
{
  echo "--- APIService metrics.k8s.io ---"
  kubectl get apiservice v1beta1.metrics.k8s.io
  echo
  echo "--- kubectl top nodes ---"
  kubectl top nodes
  echo
  echo "--- kubectl top pods ---"
  kubectl top pods -A | head -20
} | tee "${EVID_DIR}/E2-top-depois.txt"

echo
echo "metrics-server operacional. Proximo passo: ./03-deploy-app.sh"
