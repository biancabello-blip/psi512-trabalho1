# =============================================================================
# PSI512 - Trabalho Avaliativo 1
#
# Servidor web minimo, usado como carga de trabalho nas duas implantacoes.
#
# Escolha deliberada pela biblioteca padrao do Python: sem framework nao ha
# dependencias a instalar, a imagem fica pequena e o comportamento de consumo
# de CPU e simples de interpretar. O objeto de estudo do trabalho e o
# Horizontal Pod Autoscaler, e nao a aplicacao.
#
# LIMITACAO CONHECIDA, relevante para a analise do artigo:
# HTTPServer e single-thread - cada Pod atende uma requisicao por vez. Sob
# carga, portanto, o gargalo e a serializacao do atendimento, e nao a
# saturacao de um core. E justamente isso que faz o consumo de CPU por Pod
# subir depressa e acionar o HPA de forma visivel. Um servidor multi-thread
# (ThreadingHTTPServer) absorveria mais requisicoes por Pod e tornaria o
# escalonamento mais lento e menos didatico.
# =============================================================================
from http.server import SimpleHTTPRequestHandler, HTTPServer

# 0.0.0.0 e obrigatorio dentro de um container: ligar em 127.0.0.1 tornaria o
# servidor inalcancavel a partir do Service, pois o trafego chega pela
# interface de rede do Pod.
HOST = "0.0.0.0"
PORT = 8000

# SimpleHTTPRequestHandler serve os arquivos do diretorio de trabalho
# (/app, definido no Dockerfile), entregando index.html na raiz.
server = HTTPServer((HOST, PORT), SimpleHTTPRequestHandler)

print(f"Servidor iniciado em http://{HOST}:{PORT}")

try:
    server.serve_forever()
except KeyboardInterrupt:
    # Permite encerramento limpo quando o kubelet envia SIGINT/SIGTERM ao
    # remover o Pod - situacao frequente durante o scale-down do HPA.
    print("\nServidor encerrado.")
finally:
    server.server_close()
