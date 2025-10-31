from flask import Flask, jsonify
import random

app = Flask(__name__)

# Generate config code
CONFIG_CODE = f"BACKEND-{random.randint(1000, 9999)}"

@app.route('/get-config')
def get_config():
    return jsonify({'code': CONFIG_CODE, 'status': 'ready'})

@app.route('/ping')
def ping():
    return jsonify({'status': 'ok'})

@app.route('/game-over', methods=['POST'])
def game_over():
    print("Received game-over signal from frontend")
    return jsonify({'message': 'Goodbye!'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
