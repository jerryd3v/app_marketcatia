#!/usr/bin/env bash
# Build + subida a App Store Connect sin Transporter.
# 1) flutter build ipa (archiva)
# 2) xcodebuild -exportArchive con destination=upload
# Uso: ./tool/build_ios.sh
#      ./tool/build_ios.sh 1.0.17
set -euo pipefail
cd "$(dirname "$0")/.."

current=$(grep -E '^version:' pubspec.yaml | head -1 | awk '{print $2}')
name="${current%%+*}"
code="${current##*+}"
new_name="${1:-$name}"
new_code=$((code + 1))

sed -i.bak -E "s/^version: .*/version: ${new_name}+${new_code}/" pubspec.yaml
rm -f pubspec.yaml.bak

echo "Versión: ${name}+${code} → ${new_name}+${new_code}"
echo "Bundle: com.marketcatia.appMarketcatia"

cd ios && pod install && cd ..

echo "==> Archivando..."
flutter build ipa --release

export_dir="/tmp/marketcatia-upload-export-${new_code}"
rm -rf "$export_dir"
mkdir -p "$export_dir"

echo "==> Subiendo a App Store Connect..."
xcodebuild -exportArchive \
  -archivePath build/ios/archive/Runner.xcarchive \
  -exportOptionsPlist ios/ExportOptions.plist \
  -allowProvisioningUpdates \
  -exportPath "$export_dir"

echo "Listo. Build ${new_name}+${new_code} subido (revisar App Store Connect → TestFlight)."
