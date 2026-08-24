#!/bin/bash
# =============================================================================
# minikube-load-test.sh -- primeiro teste de carga do HPA (Implantacao A)
#
# Autoria original: Bianca Bello. Preservado como registro da primeira versao
# do experimento.
#
# SUPERADO por minikube/20-load-test.sh, que chama common/hpa-test.sh. Use
# aquele para gerar as evidencias. O motivo da substituicao esta abaixo, e e
# ele proprio um resultado metodologico do trabalho:
#
#   1. `kubectl get hpa -w` nao carimba horario. A saida so traz a coluna AGE,
#      arredondada em minutos, o que nao permite calcular o TEMPO DE REACAO do
#      HPA em segundos -- justamente o que o enunciado pede comparar entre os
#      dois ambientes.
#
#   2. O teste termina quando o operador aperta ENTER, junto com a carga. Como
#      o HPA so reduz replicas apos a janela de estabilizacao de 300 s, o
#      SCALE-DOWN nunca e registrado. Metade do comportamento do controlador
#      ficava invisivel.
#
#   3. Nao ha amostragem periodica: nada e gravado entre um evento e outro, o
#      que impede tracar a curva de CPU x replicas ao longo do tempo.
#
# O substituto resolve os tres pontos: tres fases cronometradas (repouso,
# carga, recuperacao), amostragem a cada 5 s em CSV com horario absoluto e
# relativo, e o mesmo script servindo as duas implantacoes -- de modo que
# nenhuma diferenca observada possa vir do roteiro de coleta.
# =============================================================================

# Diretorio de logs carimbado com a hora, para nao sobrescrever execucoes.
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_DIR="hpa-test-$TIMESTAMP"

# Abre o tunel do minikube para o Service NodePort. Fica em segundo plano
# porque o comando nao retorna: ele mantem o encaminhamento aberto.
minikube service python-web &
SERVICE_PID=$!

# Cria o diretorio antes de qualquer redirecionamento de log.
mkdir -p "$LOG_DIR"

echo "=== Iniciando teste de HPA ==="
echo "Logs serão salvos em: $LOG_DIR"

echo "[1/3] Iniciando load gen..."
# Pod avulso em laco infinito de wget contra o Service interno. Gera CPU no
# servidor, que e o que o HPA mede. --restart=Never cria um Pod, nao um Job.
kubectl run load-generator \
  --image=busybox:1.36 \
  --restart=Never \
  -- /bin/sh -c 'while true; do wget -q -O- http://python-web:8000 > /dev/null; done'

echo "[2/3] Monitorando HPA..."
# Modo watch: imprime uma linha a cada mudanca de estado do HPA.
# LIMITACAO: sem horario, so a coluna AGE em minutos. Ver o cabecalho.
kubectl get hpa -w \
  > "$LOG_DIR/hpa.log" 2>&1 &
HPA_PID=$!

echo "[3/3] Monitorando Pods..."
# Idem para os Pods, para observar a criacao das replicas novas.
kubectl get pods -w \
  > "$LOG_DIR/pods.log" 2>&1 &
PODS_PID=$!

echo ""
echo "Teste em execução."
echo "  HPA  -> $LOG_DIR/hpa.log"
echo "  Pods -> $LOG_DIR/pods.log"
echo "  Load -> $LOG_DIR/load-generator.log"
echo ""
echo "Pressione ENTER para encerrar o teste."

# Bloqueia ate o operador decidir encerrar. LIMITACAO: a carga acaba junto,
# entao a reducao de replicas (300 s depois) nunca e observada.
read

echo ""
echo "Encerrando monitoramento..."

# Encerra os tres processos de segundo plano: os dois watch e o tunel.
kill "$HPA_PID" 2>/dev/null
kill "$PODS_PID" 2>/dev/null
kill "$SERVICE_PID" 2>/dev/null

echo "Removendo CPU load..."
# Remove a carga. Sem isso o laco de wget continua consumindo CPU.
kubectl delete pod load-generator \
  > "$LOG_DIR/load-generator-delete.log" 2>&1

echo "Teste finalizado."
echo "Logs disponíveis em: $LOG_DIR"