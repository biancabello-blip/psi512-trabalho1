#!/usr/bin/env python3
# =============================================================================
# PSI512 - Trabalho Avaliativo 1
# Gera o grafico da serie temporal do HPA a partir do metricas.csv produzido
# por common/hpa-test.sh.
#
# O grafico tem dois eixos verticais porque as duas grandezas de interesse tem
# naturezas diferentes: a CPU e continua e ruidosa; o numero de replicas e
# discreto e muda em degraus. Sobrepor as duas no mesmo eixo esconderia
# justamente o que se quer mostrar - a defasagem entre a CPU cruzar o alvo e o
# HPA reagir.
#
# Uso:
#   ./plot-hpa.py <metricas.csv> [saida.png]
#   ./plot-hpa.py a.csv b.csv --comparar  (sobrepoe os dois ambientes)
# =============================================================================
import csv
import sys
from pathlib import Path

import matplotlib
matplotlib.use("Agg")          # backend sem display, para rodar via terminal
import matplotlib.pyplot as plt


def ler(caminho):
    """Le o CSV e devolve as colunas como listas. 'NA' vira None para que a
    lacuna apareca como interrupcao na curva, e nao como queda a zero."""
    t, cpu, rep, prontos, alvo = [], [], [], [], None
    with open(caminho, newline="") as fh:
        for linha in csv.DictReader(fh):
            t.append(int(linha["t_s"]) / 60.0)          # minutos
            v = linha["cpu_atual_pct"]
            cpu.append(None if v == "NA" else float(v))
            # replicas_desejadas e a DECISAO do HPA; pods_prontos e a
            # realidade observada. A defasagem entre as duas curvas e o tempo
            # de partida dos containers, e e um dos resultados do trabalho -
            # por isso as duas sao plotadas, e nao apenas uma.
            rep.append(int(linha["replicas_desejadas"]))
            prontos.append(int(linha["pods_prontos"]))
            if alvo is None and linha["cpu_alvo_pct"] != "NA":
                alvo = float(linha["cpu_alvo_pct"])
    return t, cpu, rep, prontos, alvo


def desenhar(ax, t, cpu, rep, prontos, alvo, rotulo, cor_cpu, cor_rep):
    ax.plot(t, cpu, color=cor_cpu, lw=1.4, label=f"CPU — {rotulo}")
    if alvo is not None:
        # A linha do alvo e o que torna o grafico legivel: sem ela o leitor nao
        # sabe a partir de que ponto o HPA deveria reagir.
        ax.axhline(alvo, color="gray", ls=":", lw=1)
        ax.annotate(f"alvo {alvo:.0f}%", (t[0], alvo), textcoords="offset points",
                    xytext=(2, 4), fontsize=8, color="gray")
    ax2 = ax._psi_twin
    ax2.step(t, rep, where="post", color=cor_rep, lw=1.6,
             label=f"réplicas desejadas — {rotulo}")
    ax2.step(t, prontos, where="post", color=cor_rep, lw=1.0, ls="--", alpha=0.6,
             label=f"Pods prontos — {rotulo}")


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    comparar = "--comparar" in sys.argv
    if not args:
        sys.exit("uso: plot-hpa.py <metricas.csv> [outro.csv --comparar] [saida.png]")

    csvs = [a for a in args if a.endswith(".csv")]
    saida = next((a for a in args if a.endswith(".png")), None)
    if saida is None:
        saida = str(Path(csvs[0]).with_suffix(".png"))

    fig, ax = plt.subplots(figsize=(9, 4.2))
    ax._psi_twin = ax.twinx()
    cores = [("tab:blue", "tab:red"), ("tab:green", "tab:orange")]

    for i, arquivo in enumerate(csvs if comparar else csvs[:1]):
        t, cpu, rep, prontos, alvo = ler(arquivo)
        rotulo = Path(arquivo).parent.name.replace("teste-carga-", "")
        desenhar(ax, t, cpu, rep, prontos, alvo, rotulo, *cores[i % 2])

    # Folga no topo do eixo de CPU para a legenda nao cobrir a curva.
    picos = [v for v in ax.get_lines()[0].get_ydata() if v is not None]
    if picos:
        ax.set_ylim(0, max(picos) * 1.45)

    ax.set_xlabel("tempo desde o início do experimento (min)")
    ax.set_ylabel("CPU (% do request)")
    ax._psi_twin.set_ylabel("número de Pods")
    ax._psi_twin.set_ylim(0, None)
    ax.grid(alpha=0.25)

    linhas = ax.get_legend_handles_labels()[0] + ax._psi_twin.get_legend_handles_labels()[0]
    nomes = ax.get_legend_handles_labels()[1] + ax._psi_twin.get_legend_handles_labels()[1]
    ax.legend(linhas, nomes, fontsize=8, loc="upper left", framealpha=0.9)

    fig.tight_layout()
    fig.savefig(saida, dpi=150)
    print(f"gráfico salvo em {saida}")


if __name__ == "__main__":
    main()
