FROM python:3.11-slim
WORKDIR /app
RUN pip install --no-cache-dir flask==3.0.0
COPY app.py /app/app.py
RUN mkdir -p /data
EXPOSE 5000
CMD ["python", "/app/app.py"]
