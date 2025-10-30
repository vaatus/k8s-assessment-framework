#!/usr/bin/env python3
from flask import Flask, request
import os

app = Flask(__name__)
DATA_DIR = '/data'
os.makedirs(DATA_DIR, exist_ok=True)
POD_NAME = os.environ.get('POD_NAME', 'unknown')

def get_file_path(key):
    return os.path.join(DATA_DIR, f'{key}.txt')

@app.route('/obj/<key>', methods=['POST'])
def store_data(key):
    try:
        data = request.get_data(as_text=True)
        with open(get_file_path(key), 'w') as f:
            f.write(data)
        return {'status': 'success', 'key': key, 'pod': POD_NAME}, 200
    except Exception as e:
        return {'status': 'error', 'message': str(e)}, 500

@app.route('/obj/<key>', methods=['GET'])
def get_data(key):
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
    return {'key': key, 'pod': POD_NAME, 'exists': os.path.exists(get_file_path(key))}, 200

@app.route('/health', methods=['GET'])
def health():
    return {'status': 'healthy', 'pod': POD_NAME}, 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
