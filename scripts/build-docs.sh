#!/bin/sh

sphinx-build -b html docs/source docs/build
python3 -m http.server -d docs/build
