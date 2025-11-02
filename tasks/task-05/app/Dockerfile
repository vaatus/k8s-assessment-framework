FROM python:3.11-slim

WORKDIR /app

# Install Flask
RUN pip install --no-cache-dir flask

# Copy application
COPY app.py .

# Create data directory (will be mounted by persistent volume)
RUN mkdir -p /data

# Run as non-root user
RUN useradd -m -u 1000 appuser && \
    chown -R appuser:appuser /app /data
USER appuser

EXPOSE 8080

CMD ["python", "app.py"]
