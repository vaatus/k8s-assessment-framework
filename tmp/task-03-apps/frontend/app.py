from flask import Flask, jsonify
import requests
import os
import signal
import sys
import time

app = Flask(__name__)

# Backend configuration
BACKEND_URL = "http://svc-backend.task-03.svc.cluster.local:5000"
backend_code = None

@app.route('/startup')
def startup():
    """Startup probe - retrieve config from backend"""
    global backend_code
    try:
        # Retry logic for backend connection
        max_retries = 10
        for i in range(max_retries):
            try:
                response = requests.get(f'{BACKEND_URL}/get-config', timeout=5)
                if response.status_code == 200:
                    backend_code = response.json().get('code')
                    return jsonify({'status': 'ready', 'backend_code': backend_code})
            except requests.exceptions.RequestException:
                if i < max_retries - 1:
                    time.sleep(2)
                    continue
                raise
        return jsonify({'status': 'failed'}), 500
    except Exception as e:
        return jsonify({'status': 'error', 'message': str(e)}), 500

@app.route('/who-am-i')
def who_am_i():
    """Return pod name and backend code"""
    pod_name = os.environ.get('POD_NAME', 'unknown')
    return jsonify({
        'name': pod_name,
        'code': backend_code or 'not-initialized'
    })

@app.route('/health')
def health():
    """Liveness probe - check backend connection"""
    try:
        response = requests.get(f'{BACKEND_URL}/ping', timeout=5)
        if response.status_code == 200:
            return jsonify({'status': 'healthy'})
        return jsonify({'status': 'unhealthy'}), 500
    except Exception as e:
        return jsonify({'status': 'unhealthy', 'error': str(e)}), 500

def graceful_shutdown(signum, frame):
    """Handle shutdown signal"""
    print("Received shutdown signal, calling backend /game-over...")
    try:
        requests.post(f'{BACKEND_URL}/game-over', timeout=5)
        print("Successfully notified backend")
    except Exception as e:
        print(f"Error notifying backend: {e}")
    sys.exit(0)

# Register signal handlers
signal.signal(signal.SIGTERM, graceful_shutdown)
signal.signal(signal.SIGINT, graceful_shutdown)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
