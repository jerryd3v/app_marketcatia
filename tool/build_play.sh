#!/usr/bin/env bash
# Sube versionCode (+N) en pubspec.yaml y genera el AAB para Play Store.
# Uso: ./tool/build_play.sh
#      ./tool/build_play.sh 1.1.0   # opcional: también cambia versionName
set -euo pipefail
cd "$(dirname "$0")/.."

export JAVA_HOME="${JAVA_HOME:-/Applications/Android Studio.app/Contents/jbr/Contents/Home}"
export PATH="$JAVA_HOME/bin:$PATH"

current=$(grep -E '^version:' pubspec.yaml | head -1 | awk '{print $2}')
name="${current%%+*}"
code="${current##*+}"
new_name="${1:-$name}"
new_code=$((code + 1))

sed -i.bak -E "s/^version: .*/version: ${new_name}+${new_code}/" pubspec.yaml
rm -f pubspec.yaml.bak

echo "Versión: ${name}+${code} → ${new_name}+${new_code}"
flutter build appbundle --release
echo "AAB: build/app/outputs/bundle/release/app-release.aab"
