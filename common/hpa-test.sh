#!/usr/bin/env bash
# =============================================================================
# PSI512 - Trabalho Avaliativo 1
# Instrumento de medicao do HPA - COMPARTILHADO pelas duas implantacoes.
#
# Este arquivo e chamado tanto por minikube/20-load-test.sh quanto por
# eks/20-load-test.sh. A razao de existir um script unico, e nao dois
# parecidos, e metodologica: o enunciado pede analise COMPARATIVA entre os
# dois ambientes, e uma comparacao so e valida se as duas medidas forem
# tomadas com o mesmo instrumento - mesmo periodo de amostragem, mesmas
# fases, mesmas grandezas, mesmo formato de saida. Qualquer divergencia entre
# os dois roteiros de coleta apareceria nos resultados como se fosse
# diferenca entre os ambientes.
#
# O QUE ESTE SCRIPT MEDE E POR QUE
#
# O enunciado exige "tempo de reacao do HPA". Isso nao pode ser extraido de
# "kubectl get hpa -w": aquele comando emite uma linha somente quando algum
# campo muda e nao imprime horario nenhum - a unica referencia temporal e a
# coluna AGE, arredondada em minutos. Aqui um amostrador grava, a cada 5
# segundos, uma linha CSV com o instante absoluto (UTC) e o instante relativo
# ao inicio do experimento, de onde os tempos de reacao saem por subtracao.
#
# AS TRES FASES
#
#   1. REPOUSO      - linha de base sem carga. Sem ela nao ha com o que
#                     comparar o pico, e o grafico comeca no meio da historia.
#   2. CARGA        - geradores ativos. Janela do scale-up.
#   3. RECUPERACAO  - carga removida, medicao continua. O HPA reduz replicas
#                     apenas depois da janela de estabilizacao (300 s por
#                     padrao). Um teste que encerra junto com a carga nunca
#                     registra o scale-down, e a assimetria entre subir rapido
#                     e descer devagar - que e de projeto, nao defeito - fica
#                     de fora da analise.
#
# Variaveis esperadas do chamador:
#   AMBIENTE     rotulo do ambiente (ex.: "minikube" ou "eks")
#   MANIFEST_GEN caminho do manifesto do gerador de carga
#   EVID_DIR     diretorio raiz das evidencias
#   HPA_NAME     nome do HorizontalPodAutoscaler
#   APP_LABEL    seletor de label da aplicacao (ex.: "app=python-web")
# Parametros posicionais (todos opcionais):
#   $1 repouso(s)  $2 carga(s)  $3 recuperacao(s)  $4 n. de geradores
# =============================================================================
set -euo pipefail

: "${AMBIENTE:?defina AMBIENTE}"
: "${MANIFEST_GEN:?defina MANIFEST_GEN}"
: "${EVID_DIR:?defina EVID_DIR}"
HPA_NAME="${HPA_NAME:-python-web-hpa}"
APP_LABEL="${APP_LABEL:-app=python-web}"

T_REPOUSO="${1:-60}"
T_CARGA="${2:-300}"
T_RECUP="${3:-420}"
N_GEN="${4:-1}"
INTERVALO=5

STAMP="$(date +%Y%m%d_%H%M%S)"
OUT="${EVID_DIR}/teste-carga-${AMBIENTE}-${STAMP}"
mkdir -p "${OUT}"
CSV="${OUT}/metricas.csv"
LOG="${OUT}/eventos.log"

marco() { echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) | $*" | tee -a "${LOG}"; }

amostrar() {
  local inicio=$1
  echo "t_s,hora_utc,cpu_atual_pct,cpu_alvo_pct,replicas_desejadas,replicas_atuais,pods_prontos,nodes" > "${CSV}"
  while true; do
    local agora t hora hpa cpu alvo des atu prontos nodes
    agora=$(date +%s); t=$((agora - inicio)); hora=$(date -u +%H:%M:%S)

    # Uma unica chamada a API por amostra, trazendo todos os campos do HPA de
    # uma vez. Consultas separadas veriam estados de instantes diferentes.
    hpa=$(kubectl get hpa "${HPA_NAME}" -o jsonpath='{.status.currentMetrics[0].resource.current.averageUtilization} {.spec.metrics[0].resource.target.averageUtilization} {.status.desiredReplicas} {.status.currentReplicas}' 2>/dev/null || true)
    cpu=$(echo "${hpa}" | awk '{print $1}');  alvo=$(echo "${hpa}" | awk '{print $2}')
    des=$(echo "${hpa}" | awk '{print $3}');  atu=$(echo "${hpa}"  | awk '{print $4}')

    # Vazio = o metrics-server ainda nao publicou amostra. Gravado como "NA"
    # para nao produzir campo em branco no CSV.
    [ -z "${cpu}" ] && cpu="NA"

    # Pods prontos != replicas atuais: um Pod em ContainerCreating ja conta
    # como replica para o HPA mas ainda nao atende requisicao. A diferenca
    # entre as duas colunas e o tempo de partida do container, e e justamente
    # onde Minikube e EKS mais divergem - la a imagem ja esta no daemon local,
    # aqui pode haver download do ECR.
    prontos=$(kubectl get pods -l "${APP_LABEL}" -o jsonpath='{range .items[*]}{.status.containerStatuses[0].ready}{"\n"}{end}' 2>/dev/null | grep -c true || true)
    nodes=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)

    echo "${t},${hora},${cpu},${alvo:-NA},${des:-NA},${atu:-NA},${prontos:-0},${nodes}" >> "${CSV}"
    sleep "${INTERVALO}"
  done
}

echo "=============================================================="
echo " Teste de carga do HPA - ambiente: ${AMBIENTE}"
echo " Repouso ${T_REPOUSO}s | Carga ${T_CARGA}s (${N_GEN} gerador/es) | Recuperacao ${T_RECUP}s"
echo " Saida: ${OUT}"
echo "=============================================================="

kubectl get hpa,deployment,pods,nodes -o wide > "${OUT}/estado-inicial.txt" 2>&1

INICIO=$(date +%s)
amostrar "${INICIO}" & PID_AMOSTRA=$!
kubectl get hpa  -w > "${OUT}/hpa-watch.log"  2>&1 & PID_HPA=$!
kubectl get pods -w > "${OUT}/pods-watch.log" 2>&1 & PID_PODS=$!

# Encerra os processos de fundo e remove o gerador mesmo se o script for
# interrompido. Sem isso, um Ctrl+C deixaria lacos de wget rodando - no EKS
# isso significa carga e custo continuando sem supervisao.
trap 'kill ${PID_AMOSTRA} ${PID_HPA} ${PID_PODS} 2>/dev/null || true; kubectl delete -f "${MANIFEST_GEN}" --ignore-not-found >/dev/null 2>&1 || true' EXIT

marco "FASE 1/3 repouso (${T_REPOUSO}s) - linha de base"
sleep "${T_REPOUSO}"

marco "FASE 2/3 carga (${T_CARGA}s) - aplicando ${N_GEN} gerador(es)"
kubectl apply -f "${MANIFEST_GEN}"
kubectl scale deployment/load-generator --replicas="${N_GEN}"
marco "carga ativa"
sleep "${T_CARGA}"

marco "FASE 3/3 recuperacao (${T_RECUP}s) - removendo a carga"
kubectl delete -f "${MANIFEST_GEN}" --ignore-not-found
marco "carga removida"
sleep "${T_RECUP}"
marco "FIM"

kill "${PID_AMOSTRA}" "${PID_HPA}" "${PID_PODS}" 2>/dev/null || true
sleep 1

# O describe traz o historico de decisoes com o motivo textual de cada uma
# ("New size: 5; reason: cpu resource utilization above target"), que sustenta
# a leitura do grafico no artigo.
kubectl describe hpa "${HPA_NAME}"        > "${OUT}/hpa-describe.txt"    2>&1
kubectl get pods -o wide                  > "${OUT}/estado-final.txt"    2>&1
kubectl get events --sort-by=.lastTimestamp | tail -60 > "${OUT}/eventos-cluster.txt" 2>&1

{
  echo "=== RESUMO - ambiente: ${AMBIENTE} ==="
  echo "Inicio (UTC) .....: $(date -u -d "@${INICIO}" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "${INICIO}")"
  echo "Fases ............: repouso ${T_REPOUSO}s | carga ${T_CARGA}s | recuperacao ${T_RECUP}s"
  echo "Geradores ........: ${N_GEN}"
  echo "Nodes ............: $(kubectl get nodes --no-headers | wc -l)"
  echo
  # Tempos de reacao extraidos do CSV por subtracao em relacao ao fim da fase
  # de repouso (instante em que a carga passa a existir).
  awk -F, -v tr="${T_REPOUSO}" -v tc="${T_CARGA}" 'NR>1 {
      c=($3=="NA")?0:$3+0
      if (c>cpumax) cpumax=c
      if ($6+0>repmax) repmax=$6+0
      if ($1<tr && $6+0>base) base=$6+0
      if (up=="" && $1>=tr && $6+0>base) up=$1
      if (up!="" && top=="" && $6+0==repmax) top=$1
      if ($1>=tr+tc && down=="" && $6+0<repmax) down=$1
      ult=$6+0; ultp=$7+0
    } END {
      printf "Replicas na linha de base ........: %d\n", base
      printf "CPU maxima observada .............: %d%% do request\n", cpumax
      printf "Replicas maximas .................: %d\n", repmax
      printf "Replicas / Pods prontos ao final .: %d / %d\n", ult, ultp
      if (up!="")   printf "Tempo ate a 1a expansao ..........: %d s apos o inicio da carga\n", up-tr
      if (top!="")  printf "Tempo ate o maximo ...............: %d s apos o inicio da carga\n", top-tr
      if (down!="") printf "Tempo ate a 1a reducao ...........: %d s apos a remocao da carga\n", down-(tr+tc)
      else          printf "Tempo ate a 1a reducao ...........: nao ocorreu na janela observada\n"
    }' "${CSV}"
  echo
  echo "Arquivos: metricas.csv (serie temporal) | hpa-describe.txt (motivos)"
  echo "          hpa-watch.log | pods-watch.log | eventos.log | estado-*.txt"
} | tee "${OUT}/RESUMO.txt"

echo
echo "Concluido. Evidencias em: ${OUT}"
