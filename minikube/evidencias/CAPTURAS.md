# Capturas de tela — Implantação A (Minikube)

Execução `teste-carga-minikube-20260824_124853`, 24/08/2026.
Parâmetros: 60 s repouso, 300 s carga, 420 s recuperação, 2 geradores.

| Arquivo | Momento | O que mostra |
|---|---|---|
| `A4-navegador.png` | — | Aplicação servida em `192.168.58.2:32277` (IP do node + NodePort) |
| `.../S1-pods-antes.png` | t ≈ 25 s | HPA em `cpu: 2%/10%`, 2 réplicas, 1 m de CPU por Pod |
| `.../S2-pods-durante.png` | t ≈ 230 s | HPA em `cpu: 124%/10%`, **5/5 réplicas**, os 2 geradores a ~500 m cada |
| `.../S3-pods-depois.png` | t ≈ 780 s | HPA de volta a `cpu: 2%/10%`, **1 réplica** |

As três trazem data e hora no topo e saem da **mesma execução** que gerou o
`metricas.csv` e o `RESUMO.txt` desse diretório, de modo que os números das
capturas conferem com os do artigo.

A execução anterior (`teste-carga-minikube-20260823_181436`) foi mantida no
repositório: duas execuções independentes do mesmo ambiente, com resultados
próximos (expandir 48 s vs 46 s, reduzir 395 s vs 388 s), são evidência da
repetibilidade da medida.
