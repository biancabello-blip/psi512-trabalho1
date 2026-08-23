#!/usr/bin/env bash
# =============================================================================
# PSI512 - Trabalho Avaliativo 1 - Implantacao B (AWS EKS)
# Etapa 3: implantar a aplicacao, o Service e o HPA.
#
# Equivalente ao deploy-minikube.sh da Implantacao A.
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")"
source ./00-config.sh
mkdir -p "${EVID_DIR}"

# O manifesto versionado traz o placeholder __IMAGE__ para nao gravar o account
# ID no repositorio. A substituicao ocorre aqui, em um arquivo temporario, e o
# resultado tambem e salvo como evidencia do que foi de fato aplicado.
echo "== Gerando o manifesto com a imagem ${IMAGE}"
sed "s|__IMAGE__|${IMAGE}|" 10-deployment.yaml > /tmp/psi512-deployment.yaml

# Validacao no servidor antes de aplicar: detecta erro de sintaxe ou de schema
# sem criar nada no cluster.
echo "== Validando (dry-run no servidor)"
kubectl apply -f /tmp/psi512-deployment.yaml --dry-run=server
kubectl apply -f 11-service-lb.yaml --dry-run=server

echo
echo "== Aplicando Deployment + HPA"
kubectl apply -f /tmp/psi512-deployment.yaml
cp /tmp/psi512-deployment.yaml "${EVID_DIR}/E3-deployment-aplicado.yaml"

echo
echo "== Aplicando o Service do tipo LoadBalancer"
kubectl apply -f 11-service-lb.yaml

echo
echo "== Aguardando os Pods ficarem prontos"
kubectl rollout status deployment/python-web --timeout=180s

echo
echo "== EVIDENCIA: cadeia de objetos criada por um unico apply"
{
  kubectl get deployment,replicaset,pod -l app=python-web -o wide
  echo
  kubectl get hpa python-web-hpa
  echo
  kubectl get endpointslice -l kubernetes.io/service-name=python-web
} | tee "${EVID_DIR}/E3-objetos.txt"

echo
echo "== Aguardando o balanceador de carga receber um nome DNS (ate 5 min)"
# O campo status.loadBalancer.ingress[0].hostname so e preenchido depois que o
# cloud controller conclui a criacao do balanceador na AWS. O laco espera por
# esse preenchimento em vez de usar um sleep fixo.
for i in $(seq 1 60); do
  LB_HOST="$(kubectl get svc python-web -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)"
  [ -n "${LB_HOST}" ] && break
  sleep 5
done

if [ -z "${LB_HOST:-}" ]; then
  echo "AVISO: o balanceador ainda nao publicou um hostname. Verifique com:"
  echo "  kubectl describe svc python-web"
else
  echo "Balanceador: ${LB_HOST}"
  echo
  echo "== EVIDENCIA: Service e eventos do cloud controller"
  kubectl describe svc python-web | tee "${EVID_DIR}/E3-service-lb.txt"

  # O registro DNS do balanceador leva 1-3 minutos para propagar mesmo depois
  # de o hostname aparecer no Service. O laco tenta ate obter resposta HTTP.
  echo
  echo "== Aguardando a aplicacao responder pela internet"
  for i in $(seq 1 60); do
    if curl -s -m 5 "http://${LB_HOST}/" | grep -q "Ola, mundo\|Olá, mundo"; then
      echo "Aplicacao respondendo em http://${LB_HOST}/"
      {
        echo "URL: http://${LB_HOST}/"
        date -u +"Coleta em %Y-%m-%dT%H:%M:%SZ"
        echo "---"
        curl -s -i -m 10 "http://${LB_HOST}/"
      } | tee "${EVID_DIR}/E4-acesso-externo.txt"
      break
    fi
    sleep 5
  done
fi

echo
echo "== ABRA NO NAVEGADOR E TIRE UM SCREENSHOT (evidencia obrigatoria):"
echo "   http://${LB_HOST:-<pendente>}/"
echo
echo "Proximo passo: ./20-load-test.sh"
