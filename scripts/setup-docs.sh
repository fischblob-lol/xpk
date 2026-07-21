#!/bin/sh

set -e

python3 -m venv .venv

. .venv/bin/activate

python -m pip install --upgrade pip

python -m pip install furo

echo "run this for virtual env: source .venv/bin/activate"
