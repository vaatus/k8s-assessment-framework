#!/bin/bash
#
# JWT Token Decoder - Shell Wrapper
# Decodes evaluation tokens from students
#

set -e

# Check if Python 3 is available
if ! command -v python3 &> /dev/null; then
    echo "Error: python3 is required but not found"
    exit 1
fi

# Install PyJWT if not available
if ! python3 -c "import jwt" 2>/dev/null; then
    echo "Installing PyJWT..."
    pip3 install PyJWT
fi

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Run the Python decoder
python3 "${SCRIPT_DIR}/decode-jwt-token.py" "$@"
