#!/usr/bin/env bash

set -euo pipefail

DELAY=60

while true; do
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Running: just apply -auto-approve"

  if just apply -auto-approve; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Command succeeded (exit 0). Exiting."
    exit 0
  else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Command failed. Retrying in ${DELAY}s..."
    sleep "$DELAY"
  fi
done
