#!/usr/bin/env bash
# Arranca el Simulator de iOS (por defecto iPhone 17 Pro).
# Uso: ./tool/start_simulator.sh
#      ./tool/start_simulator.sh "iPad Pro 11-inch (M5)"
set -euo pipefail

NAME="${1:-iPhone 17 Pro}"

# Si ya está booted, simctl boot falla: lo ignoramos.
xcrun simctl boot "$NAME" 2>/dev/null || true
open -a Simulator
echo "Simulator listo: $NAME"
echo "Luego: ./tool/run_app.sh"
