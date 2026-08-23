#!/usr/bin/env bash
# =============================================================================
# PSI512 - Trabalho Avaliativo 1
# Extrai do metricas.csv os numeros que entram no artigo.
#
# Separado de hpa-test.sh de proposito: assim a analise pode ser refeita sobre
# um experimento ja coletado, sem repetir o experimento. Isso importa porque a
# execucao no EKS tem custo e nao deve ser repetida so para corrigir uma conta.
#
# Uso: ./resumo.sh <metricas.csv> <ambiente> <repouso_s> <carga_s> <geradores>
#
# DUAS MEDIDAS DE TEMPO DE REACAO, e nao uma:
#
#   - Tempo ate a DECISAO: quando replicas_desejadas passa da linha de base.
#     Mede o controlador - o intervalo de sincronizacao do HPA (15 s por
#     padrao) somado a defasagem do metrics-server, que publica medias sobre
#     janela deslizante e portanto so reflete a carga alguns segundos depois.
#
#   - Tempo ate os PODS PRONTOS no novo patamar: quando pods_prontos alcanca o
#     numero decidido. Mede o controlador MAIS o substrato: agendamento,
#     obtencao da imagem e partida do container.
#
# A diferenca entre as duas e o que separa "o Kubernetes decidiu escalar" de
# "a aplicacao passou a atender com mais replicas" - e e onde Minikube e EKS
# devem divergir, ja que la a imagem esta no daemon local e aqui vem do ECR
# pela rede. Reportar apenas uma das duas esconderia esse efeito.
# =============================================================================
set -euo pipefail

CSV="${1:?informe o metricas.csv}"
AMBIENTE="${2:-?}"
T_REPOUSO="${3:-60}"
T_CARGA="${4:-300}"
N_GEN="${5:-?}"

echo "=== RESUMO - ambiente: ${AMBIENTE} ==="
echo "Fases ......................: repouso ${T_REPOUSO}s | carga ${T_CARGA}s"
echo "Geradores de carga .........: ${N_GEN}"
echo

# Duas passagens sobre o arquivo: a primeira guarda as amostras, a segunda
# calcula. Em uma passagem unica os maximos ainda nao sao conhecidos quando as
# comparacoes acontecem, e os tempos saem subestimados.
awk -F, -v tr="${T_REPOUSO}" -v tc="${T_CARGA}" '
NR>1 {
  n++
  t[n]=$1+0
  cpu[n]=($3=="NA")?-1:$3+0
  des[n]=($5=="NA")?0:$5+0
  atu[n]=($6=="NA")?0:$6+0
  pron[n]=$7+0
  if (t[n] < tr && des[n] > base) base = des[n]   # patamar antes da carga
  if (cpu[n] > cpumax) cpumax = cpu[n]
  if (des[n] > desmax) desmax = des[n]            # pico decidido pelo HPA
  if (pron[n] > pronmax) pronmax = pron[n]
}
END {
  t_carga_ini = tr
  t_carga_fim = tr + tc

  for (i = 1; i <= n; i++) {
    # --- subida ---
    if (t[i] >= t_carga_ini) {
      if (t_dec == 0 && des[i] > base)      t_dec  = t[i]   # 1a decisao de expandir
      if (t_pico == 0 && des[i] >= desmax)  t_pico = t[i]   # decidiu o maximo
      if (t_ok == 0 && pron[i] >= desmax)   t_ok   = t[i]   # Pods prontos no maximo
    }
    # --- descida ---
    if (t[i] >= t_carga_fim) {
      if (t_red == 0 && des[i] < desmax)    t_red  = t[i]   # 1a decisao de reduzir
    }
    ultd = des[i]; ultp = pron[i]
  }

  printf "Replicas na linha de base ..........: %d\n", base
  printf "CPU maxima observada ...............: %d%% do request\n", cpumax
  printf "Replicas maximas decididas pelo HPA : %d\n", desmax
  printf "Pods prontos no pico ...............: %d\n", pronmax
  printf "\n-- Subida (referencia: inicio da carga) --\n"
  if (t_dec)  printf "Decisao de expandir ................: %d s\n", t_dec  - t_carga_ini
  if (t_pico) printf "Decisao de ir ao maximo ............: %d s\n", t_pico - t_carga_ini
  if (t_ok)   printf "Pods prontos no maximo .............: %d s\n", t_ok   - t_carga_ini
  if (t_ok && t_pico) {
    d = t_ok - t_pico
    # Zero nao significa instantaneo: significa que a partida dos containers
    # coube dentro de um unico intervalo de amostragem (5 s).
    if (d == 0) printf "  -> custo do substrato (prontos - decisao): < 5 s (abaixo da resolucao de amostragem)\n"
    else        printf "  -> custo do substrato (prontos - decisao): %d s\n", d
  }
  printf "\n-- Descida (referencia: remocao da carga) --\n"
  if (t_red) printf "Decisao de reduzir .................: %d s\n", t_red - t_carga_fim
  else       printf "Decisao de reduzir .................: nao ocorreu na janela observada\n"
  printf "\nEstado na ultima amostra ...........: %d replicas decididas, %d Pods ainda prontos\n", ultd, ultp
  printf "  (Pods em Terminating continuam prontos por alguns segundos apos a decisao de reduzir)\n"
}' "${CSV}"
