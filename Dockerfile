FROM python:3.12-alpine

WORKDIR /app

COPY app.py .
COPY index.html .

EXPOSE 8000

CMD ["python", "app.py"]