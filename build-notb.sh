#!/usr/bin/env bash
# Historical filename retained as a wrapper; this branch targets A15 Treble.
set -euo pipefail
cd "$(dirname "$0")"
bash scripts/build-tissot.sh
bash scripts/package-tissot.sh
