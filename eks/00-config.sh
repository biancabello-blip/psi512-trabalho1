#!/usr/bin/env bash
# =============================================================================
# PSI512 - Trabalho Avaliativo 1 - Implantacao B (AWS EKS)
#
# Variaveis compartilhadas por todos os scripts desta pasta.
# Carregado com "source 00-config.sh" pelos demais scripts.
#
# Nenhum identificador de conta, chave ou token e gravado aqui. O account ID
# e descoberto em tempo de execucao a partir da sessao autenticada da AWS CLI,
# de modo que este arquivo pode ser versionado no GitHub sem exposicao.
# =============================================================================

# Regiao usada em todo o trabalho. Alterar aqui propaga para todos os scripts.
export AWS_REGION="${AWS_REGION:-us-east-1}"

# Nome do cluster EKS.
export CLUSTER_NAME="${CLUSTER_NAME:-psi512-t1-eks}"

# Tipo e quantidade de instancias do managed node group.
# Dois nodes, e nao um: com maxReplicas=5 um unico t3.medium ja seria
# suficiente em capacidade, mas com dois nodes e possivel observar o scheduler
# distribuindo os Pods criados pelo HPA entre maquinas distintas - fenomeno que
# nao existe no Minikube, que tem um unico node. Essa diferenca e um dos pontos
# da analise comparativa do artigo.
export NODE_TYPE="${NODE_TYPE:-t3.medium}"
export NODE_COUNT="${NODE_COUNT:-2}"

# Repositorio no Amazon ECR onde a imagem da aplicacao sera publicada.
export ECR_REPO="${ECR_REPO:-psi512-python-web}"
export IMAGE_TAG="${IMAGE_TAG:-1.0}"

# Descoberto em tempo de execucao (nao versionado).
export AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text 2>/dev/null)"
export ECR_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}"
export IMAGE="${ECR_URI}:${IMAGE_TAG}"

# Diretorio raiz das evidencias.
export EVID_DIR="${EVID_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/evidencias}"
