# Artigo técnico — modelo SBC

Esqueleto pronto para os três escreverem em paralelo. Já traz o modelo oficial
da SBC (`sbc-template.sty`, `caption2.sty`, `sbc.bst`), a estrutura das seis
seções, as tabelas montadas e a figura da Implantação A.

## Overleaf — como subir

1. Compacte esta pasta:
   ```bash
   cd artigo && zip -r ../artigo-sbc.zip .
   ```
2. No Overleaf: **New Project → Upload Project** → selecione o zip.
3. **Menu → Compiler → pdfLaTeX** (é o compilador certo para este modelo).
4. **Share** → convide os outros dois com permissão de edição.

Compila sem erro já na primeira vez — o esqueleto está fechado, só faltam os
textos.

## Divisão do trabalho

Cada seção tem, no `.tex`, um comentário dizendo quem escreve, qual o tamanho
alvo e o que precisa aparecer ali. Escreva só dentro da sua seção: o Overleaf
edita em tempo real, mas duas pessoas no mesmo parágrafo continua sendo
confusão.

| Seção | Responsável | Alvo |
|---|---|---|
| 1. Introdução | Bianca | 1,0 pág |
| 2. Fundamentação | Bianca | 0,75 pág |
| 3. Arquitetura e topologia | terceiro integrante | 1,5 pág |
| 4. Metodologia | terceiro integrante | 1,0 pág |
| 5. Resultados e análise comparativa | Franco | 2,0 pág |
| 6. Conclusões | Franco | 0,5 pág |
| Resumo / abstract | quem integrar, **por último** | ~100 palavras |

Soma ~6,75 páginas contra o mínimo de 6. A folga é pequena — não corte antes
de ver o PDF paginado.

Quem escreve as seções 3 e 4 não precisa ter montado a infraestrutura: as
fontes são o [`README.md`](../README.md) da raiz, o
[`eks/README.md`](../eks/README.md) e o
[`docs/GUIA-EXECUCAO.md`](../docs/GUIA-EXECUCAO.md), que descrevem topologia,
manifestos e método em detalhe.

## Marcações no texto

- `[PREENCHER]` — número que só existe depois da execução no EKS.
- `[TERCEIRO INTEGRANTE]` — nome e e-mail a completar no bloco de autoria.
- Os comentários `%` com o roteiro de cada seção **devem ser apagados** à
  medida que o texto entra.

## Uma correção já aplicada

O modelo oficial da SBC carrega `inputenc` duas vezes — `utf8` e depois
`latin1`. O segundo prevalece e quebra todos os acentos. No `artigo.tex` ficou
só `utf8`. Se alguém copiar o preâmbulo do template original por cima, o
problema volta.

## Figuras

`figuras/hpa-minikube.png` já está lá. O gráfico do EKS entra como
`figuras/hpa-eks.png` e o `\includegraphics` correspondente está comentado no
final da Seção 5, pronto para descomentar.

Para gerar o comparativo com as duas curvas sobrepostas:

```bash
common/plot-hpa.py \
  minikube/evidencias/*/teste-carga-minikube-*/metricas.csv \
  eks/evidencias/*/teste-carga-eks-*/metricas.csv \
  --comparar artigo/figuras/comparativo.png
```
