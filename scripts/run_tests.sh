#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
make test
(cd digital-twin && npm run test && npm run build)
echo "ALL CHECKS PASSED"
