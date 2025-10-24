#!/usr/bin/env python3
"""
Simple key-value store with persistent storage for task-02
Implements POST /obj/<key>, GET /obj/<key>, and GET /location/<key>
"""

from flask import Flask, request
import os
import json

app = Flask(__name__)

# Data directory (mounted from PVC)
DATA_DIR = '/data'
os.makedirs(DATA_DIR, exist_ok=True)

# Get pod name from environment
POD_NAME = os.environ.get('POD_NAME', 'unknown')

def get_file_path(key):
    """Get file path for a key"""
    return os.path.join(DATA_DIR, f'{key}.txt')

@app.route('/obj/<key>', methods=['POST'])
def store_data(key):
    """Store data for a key"""
    try:
        data = request.get_data(as_text=True)
        file_path = get_file_path(key)

        with open(file_path, 'w') as f:
            f.write(data)

        return {'status': 'success', 'key': key, 'pod': POD_NAME}, 200
    except Exception as e:
        return {'status': 'error', 'message': str(e)}, 500

@app.route('/obj/<key>', methods=['GET'])
def get_data(key):
    """Retrieve data for a key"""
    try:
        file_path = get_file_path(key)

        if not os.path.exists(file_path):
            return {'status': 'not_found', 'key': key}, 404

        with open(file_path, 'r') as f:
            data = f.read()

        return data, 200
    except Exception as e:
        return {'status': 'error', 'message': str(e)}, 500

@app.route('/location/<key>', methods=['GET'])
def get_location(key):
    """Return which pod stores the key"""
    try:
        file_path = get_file_path(key)
        exists = os.path.exists(file_path)

        return {
            'key': key,
            'pod': POD_NAME,
            'exists': exists
        }, 200
    except Exception as e:
        return {'status': 'error', 'message': str(e)}, 500

@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return {'status': 'healthy', 'pod': POD_NAME}, 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
