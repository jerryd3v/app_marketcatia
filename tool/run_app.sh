#!/usr/bin/env bash
# Corre la app en un dispositivo (por defecto iPhone 17 Pro).
# Uso: ./tool/run_app.sh
#      ./tool/run_app.sh "iPad Pro 11-inch (M5)"
#      ./tool/run_app.sh <device_id>
set -euo pipefail
cd "$(dirname "$0")/.."

DEVICE="${1:-iPhone 17 Pro}"

# Firebase SPM exige iOS 15; Flutter regenera Package.swift en 13.
PKG="ios/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/Package.swift"
if [[ -f "$PKG" ]]; then
  sed -i '' 's/\.iOS("13.0")/.iOS("15.0")/' "$PKG"
fi

echo "flutter run -d \"$DEVICE\""
exec flutter run -d "$DEVICE"
