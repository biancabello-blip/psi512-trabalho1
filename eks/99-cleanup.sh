#!/usr/bin/env bash
# =============================================================================
# PSI512 - Trabalho Avaliativo 1 - Implantacao B (AWS EKS)
# Etapa 5: remocao completa dos recursos.
#
# A ORDEM IMPORTA E NAO E ARBITRARIA.
#
# O balanceador de carga nao pertence ao CloudFormation: ele foi criado pelo
# cloud controller do Kubernetes em resposta ao objeto Service. Se o cluster
# for excluido primeiro, o controlador deixa de existir e o balanceador
# permanece na conta - orfao, invisivel no console do EKS e cobrado por hora
# ate ser removido a mao. Por isso o Service e apagado ANTES do cluster, e o
# script espera ate confirmar que o numero de balanceadores chegou a zero.
#
# Ao final o script verifica, por chamada de API, que nada sobrou. Verificacao
# vazia comprova ausencia de recursos, nao ausencia de cobranca: o Billing tem
# atraso de atualizacao e deve ser reconferido nos dias seguintes.
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")"
source ./00-config.sh
mkdir -p "${EVID_DIR}"

echo "== [1/5] Removendo o gerador de carga (se ainda existir)"
kubectl delete -f 12-load-generator.yaml --ignore-not-found || true

echo
echo "== [2/5] Removendo o Service do tipo LoadBalancer"
kubectl delete -f 11-service-lb.yaml --ignore-not-found || true

echo "   aguardando a AWS destruir o balanceador..."
for i in $(seq 1 60); do
  N_CLB=$(aws elb describe-load-balancers --region "${AWS_REGION}" \
            --query 'length(LoadBalancerDescriptions)' --output text 2>/dev/null || echo 0)
  N_ELBV2=$(aws elbv2 describe-load-balancers --region "${AWS_REGION}" \
            --query 'length(LoadBalancers)' --output text 2>/dev/null || echo 0)
  echo "   balanceadores restantes: classic=${N_CLB} v2=${N_ELBV2}"
  [ "${N_CLB}" = "0" ] && [ "${N_ELBV2}" = "0" ] && break
  sleep 10
done

echo
echo "== [3/5] Removendo a aplicacao e o HPA"
kubectl delete hpa python-web-hpa --ignore-not-found || true
kubectl delete deployment python-web --ignore-not-found || true

echo
echo "== [4/5] Removendo o cluster (node group, plano de controle, VPC, roles)"
echo "   isso leva cerca de 10 minutos"
eksctl delete cluster --name "${CLUSTER_NAME}" --region "${AWS_REGION}" --wait

echo
echo "== [5/5] Removendo o repositorio de imagens do ECR"
# --force porque o repositorio contem imagens; sem a flag a exclusao e negada.
aws ecr delete-repository --repository-name "${ECR_REPO}" \
  --region "${AWS_REGION}" --force >/dev/null 2>&1 || true

echo
echo "== EVIDENCIA: verificacao final (todas as listas devem sair vazias)"
{
  echo "--- clusters EKS ---"
  aws eks list-clusters --region "${AWS_REGION}" --query clusters --output text
  echo "--- instancias EC2 em execucao ---"
  aws ec2 describe-instances --region "${AWS_REGION}" \
    --filters Name=instance-state-name,Values=running \
    --query 'Reservations[].Instances[].InstanceId' --output text
  echo "--- balanceadores classic ---"
  aws elb describe-load-balancers --region "${AWS_REGION}" \
    --query 'LoadBalancerDescriptions[].LoadBalancerName' --output text
  echo "--- balanceadores v2 (ALB/NLB) ---"
  aws elbv2 describe-load-balancers --region "${AWS_REGION}" \
    --query 'LoadBalancers[].LoadBalancerName' --output text
  echo "--- volumes EBS disponiveis ---"
  aws ec2 describe-volumes --region "${AWS_REGION}" \
    --query 'Volumes[].VolumeId' --output text
  echo "--- repositorios ECR ---"
  aws ecr describe-repositories --region "${AWS_REGION}" \
    --query 'repositories[].repositoryName' --output text 2>/dev/null || echo "(nenhum)"
  echo "--- pilhas CloudFormation ativas ---"
  aws cloudformation list-stacks --region "${AWS_REGION}" \
    --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE \
    --query 'StackSummaries[].StackName' --output text
  echo "--- roles IAM do trabalho ---"
  aws iam list-roles --query "Roles[?contains(RoleName,'${CLUSTER_NAME}')].RoleName" --output text
  echo "--- instance profiles do trabalho ---"
  aws iam list-instance-profiles \
    --query "InstanceProfiles[?contains(InstanceProfileName,'${CLUSTER_NAME}')].InstanceProfileName" --output text
} | tee "${EVID_DIR}/E9-limpeza.txt"

echo
echo "Limpeza concluida. Confira o Billing nos proximos dias."
echo "Se voce criou uma access key para este trabalho, apague-a agora:"
echo "  aws iam list-access-keys"
echo "  aws iam delete-access-key --access-key-id <ID>"
