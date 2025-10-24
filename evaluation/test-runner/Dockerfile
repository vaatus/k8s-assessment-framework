FROM python:3.11-slim

WORKDIR /app

# Install required packages
RUN pip install --no-cache-dir requests==2.31.0

# Copy test runner
COPY test_runner.py /app/test_runner.py
RUN chmod +x /app/test_runner.py

# Run as non-root user
RUN useradd -m -u 1000 testrunner
USER testrunner

ENTRYPOINT ["python3", "/app/test_runner.py"]
