FROM python:3.11-slim

WORKDIR /app

# Install Flask
RUN pip install --no-cache-dir flask==3.0.0

# Copy application
COPY app.py /app/app.py

# Create data directory
RUN mkdir -p /data

# Expose port
EXPOSE 5000

# Run application
CMD ["python", "/app/app.py"]
