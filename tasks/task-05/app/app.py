#!/usr/bin/env python3
"""
Stateful Counter Application
Demonstrates StatefulSet with persistent storage
"""

from flask import Flask, jsonify, request
import os
import fcntl

app = Flask(__name__)

COUNTER_FILE = '/data/counter.txt'
POD_NAME = os.environ.get('POD_NAME', 'unknown')


def read_counter():
    """Read counter value from file with file locking"""
    try:
        with open(COUNTER_FILE, 'r') as f:
            fcntl.flock(f.fileno(), fcntl.LOCK_SH)
            try:
                value = int(f.read().strip())
            finally:
                fcntl.flock(f.fileno(), fcntl.LOCK_UN)
        return value
    except (FileNotFoundError, ValueError):
        return 0


def write_counter(value):
    """Write counter value to file with file locking"""
    with open(COUNTER_FILE, 'w') as f:
        fcntl.flock(f.fileno(), fcntl.LOCK_EX)
        try:
            f.write(str(value))
            f.flush()
            os.fsync(f.fileno())
        finally:
            fcntl.flock(f.fileno(), fcntl.LOCK_UN)


@app.route('/ready')
def ready():
    """Readiness probe - checks if counter file exists"""
    if os.path.exists(COUNTER_FILE):
        return jsonify({'status': 'ready', 'pod_name': POD_NAME}), 200
    else:
        return jsonify({'status': 'not ready', 'reason': 'counter file not found'}), 503


@app.route('/count')
def get_count():
    """Get current counter value"""
    count = read_counter()
    return jsonify({
        'count': count,
        'pod_name': POD_NAME
    }), 200


@app.route('/increment', methods=['POST'])
def increment():
    """Increment counter by 1"""
    count = read_counter()
    count += 1
    write_counter(count)
    return jsonify({
        'count': count,
        'pod_name': POD_NAME,
        'message': 'Counter incremented'
    }), 200


@app.route('/reset', methods=['POST'])
def reset():
    """Reset counter to 0"""
    write_counter(0)
    return jsonify({
        'count': 0,
        'pod_name': POD_NAME,
        'message': 'Counter reset'
    }), 200


@app.route('/health')
def health():
    """Health check endpoint"""
    return jsonify({'status': 'healthy', 'pod_name': POD_NAME}), 200


if __name__ == '__main__':
    # Wait for counter file to exist (created by init container)
    import time
    max_wait = 30
    waited = 0
    while not os.path.exists(COUNTER_FILE) and waited < max_wait:
        print(f"Waiting for counter file to be initialized... ({waited}s)")
        time.sleep(1)
        waited += 1

    if not os.path.exists(COUNTER_FILE):
        print("Warning: Counter file not found, creating with value 0")
        write_counter(0)

    print(f"Starting counter app on pod: {POD_NAME}")
    print(f"Counter file: {COUNTER_FILE}")
    print(f"Initial count: {read_counter()}")

    app.run(host='0.0.0.0', port=8080)
