# =============================================================================
# PSI512 - Trabalho Avaliativo 1
#
# Imagem da aplicacao web. Usada SEM ALTERACAO nas duas implantacoes: no
# Minikube ela e construida dentro do daemon da VM; no EKS a mesma definicao e
# construida e enviada ao Amazon ECR. Manter uma unica imagem garante que a
# comparacao entre os ambientes nao seja contaminada por diferenca de software.
# =============================================================================

# Alpine reduz a imagem a ~50 MB. O tamanho importa no experimento: no EKS a
# imagem e baixada do registro por cada node, e esse download entra no tempo
# entre o HPA decidir criar um Pod e o Pod comecar a atender.
FROM python:3.12-alpine

WORKDIR /app

# Apenas dois arquivos: o servidor e a pagina que ele serve. Nao ha
# dependencias externas - o modulo http.server faz parte da biblioteca padrao,
# o que dispensa requirements.txt e etapa de instalacao.
COPY app.py .
COPY index.html .

# Documenta a porta usada pelo servidor. EXPOSE nao publica nada por si: quem
# torna a porta alcancavel e o campo containerPort do Deployment e o Service.
EXPOSE 8000

CMD ["python", "app.py"]
