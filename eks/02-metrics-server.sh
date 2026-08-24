#!/usr/bin/env bash
# =============================================================================
# PSI512 - Trabalho Avaliativo 1 - Implantacao B (AWS EKS)
# Etapa 2: garantir o metrics-server.
#
# O HPA nao mede CPU por conta propria: consulta a API metrics.k8s.io, que so
# existe se houver um servidor de metricas registrado como APIService. No
# Minikube isso e um addon de uma linha. No EKS ha DOIS cenarios possiveis, e
# aplicar o tratamento errado quebra o cluster:
#
#   (a) O cluster ja traz o metrics-server como ADDON GERENCIADO da AWS.
#       Clusters criados por eksctl em versoes recentes caem neste caso - o
#       componente aparece em "aws eks list-addons" e os objetos vem rotulados
#       com app.kubernetes.io/managed-by=EKS.
#
#   (b) O cluster NAO tem metrics-server. E preciso aplicar o manifesto oficial
#       do projeto, como descreve a documentacao da AWS citada no enunciado.
#
# POR QUE ISSO IMPORTA (aprendido na pratica, nao na teoria):
# aplicar o manifesto oficial por cima do addon gerenciado NAO e inofensivo. O
# Deployment falha (o seletor de labels e imutavel e os nomes de porta
# divergem), mas o SERVICE e o APISERVICE sao alterados antes disso - e o
# Service passa a apontar para um nome de porta que os Pods do addon nao
# expoem. O resultado e um metrics-server saudavel (2/2 Running) com a API de
# metricas fora do ar:
#
#   endpointslices for service/metrics-server in "kube-system"
#   have no addresses with port name "https"
#
# e o HPA permanece em <unknown> sem nenhum sintoma obvio. A recuperacao exige
#   aws eks update-addon --addon-name metrics-server --resolve-conflicts OVERWRITE
#
# Por isso este script DETECTA o cenario antes de agir.
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")"
source ./00-config.sh
mkdir -p "${EVID_DIR}"

echo "== EVIDENCIA: estado ANTES"
# "|| true" porque o comando falha quando a API de metricas ainda nao responde;
# esse erro e a evidencia que se quer registrar, nao uma falha do script.
kubectl top nodes 2>&1 | tee "${EVID_DIR}/E2-top-antes.txt" || true

echo
echo "== Verificando se o metrics-server e um addon gerenciado pelo EKS"
if aws eks list-addons --cluster-name "${CLUSTER_NAME}" --region "${AWS_REGION}" \
     --query 'addons' --output text 2>/dev/null | grep -qw metrics-server; then

  echo "   SIM - addon gerenciado detectado. O manifesto oficial NAO sera"
  echo "   aplicado: sobrepor os dois quebra a API de metricas."
  MODO="addon gerenciado pela AWS"

  # Garante que o addon esteja integro. OVERWRITE faz o EKS reconciliar os
  # proprios manifestos, desfazendo qualquer alteracao manual anterior.
  aws eks update-addon --cluster-name "${CLUSTER_NAME}" --region "${AWS_REGION}" \
    --addon-name metrics-server --resolve-conflicts OVERWRITE >/dev/null 2>&1 || true

  for i in $(seq 1 30); do
    S=$(aws eks describe-addon --cluster-name "${CLUSTER_NAME}" --region "${AWS_REGION}" \
          --addon-name metrics-server --query 'addon.status' --output text 2>/dev/null || echo UNKNOWN)
    echo "   addon: ${S}"
    [ "${S}" = "ACTIVE" ] && break
    sleep 10
  done
else
  echo "   NAO - instalando o manifesto oficial do projeto metrics-server,"
  echo "   conforme a documentacao da AWS referenciada no enunciado."
  MODO="manifesto oficial aplicado manualmente"
  kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
  kubectl -n kube-system rollout status deployment/metrics-server --timeout=180s
fi

# Em qualquer dos dois caminhos, a API leva alguns segundos para publicar a
# primeira janela de amostras depois que os Pods ficam prontos. O laco espera
# pelo dado, e nao por um tempo fixo.
echo
echo "== Aguardando a primeira coleta de metricas"
for i in $(seq 1 30); do
  kubectl top nodes >/dev/null 2>&1 && break
  sleep 10
done

echo
echo "== EVIDENCIA: estado DEPOIS"
{
  echo "Origem do metrics-server: ${MODO}"
  echo
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
echo "metrics-server operacional (${MODO}). Proximo: ./03-deploy-app.sh"
