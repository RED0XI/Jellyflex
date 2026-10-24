#!/bin/bash
# Baut die macOS-Version (Apple Silicon + Intel) und daraus in dist/:
#   Jellyflex-<Version>.dmg            zum Herunterladen und Installieren
#   Jellyflex-<Version>-macOS.zip      für das Update in der App (+ .sig)
#
# Start:  tool/build_macos.sh
#
# Optional über Umgebungsvariablen (in GitHub Actions als Secrets gesetzt):
#   MACOS_SIGN_IDENTITY   z. B. "Developer ID Application: Vorname Name (TEAMID1234)"
#                         → signiert mit Hardened Runtime (sonst nur ad hoc)
#   APPLE_ID, APPLE_TEAM_ID, APPLE_APP_PASSWORD
#                         → lässt die App von Apple beglaubigen (notarisieren) und heftet
#                           das Ticket an – dann öffnet sie ohne Gatekeeper-Warnung
#   JELLYFLEX_UPDATE_SIGNING_KEY (oder die Schlüsseldatei, siehe tool/sign_update.dart)
#                         → signiert das Update-Paket (Ed25519)
set -euo pipefail
cd "$(dirname "$0")/.."

version=$(sed -n 's/^version:[[:space:]]*\([0-9.]*\).*/\1/p' pubspec.yaml)
echo "Baue Jellyflex $version für macOS ..."
flutter build macos --release

stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
# ditto behält Symlinks und Rechte in den Frameworks bei.
ditto build/macos/Build/Products/Release/Jellyflex.app "$stage/Jellyflex.app"
app="$stage/Jellyflex.app"
mkdir -p dist
zip="dist/Jellyflex-$version-macOS.zip"
dmg="dist/Jellyflex-$version.dmg"
rm -f "$zip" "$zip.sig" "$dmg"

if [ -n "${MACOS_SIGN_IDENTITY:-}" ]; then
  echo "Signiere mit: $MACOS_SIGN_IDENTITY"
  sign() { codesign --force --timestamp --options runtime --sign "$MACOS_SIGN_IDENTITY" "$@"; }
  # Erst alles Eingebettete, dann die App selbst.
  for framework in "$app"/Contents/Frameworks/*.framework; do sign "$framework"; done
  sign --entitlements macos/Runner/Release.entitlements "$app"
else
  echo "Kein MACOS_SIGN_IDENTITY – nur ad hoc signiert (Gatekeeper warnt beim ersten Öffnen)."
fi
codesign --verify --deep --strict "$app"

notarize() {
  xcrun notarytool submit "$1" --apple-id "$APPLE_ID" --team-id "$APPLE_TEAM_ID" \
    --password "$APPLE_APP_PASSWORD" --wait --timeout 30m
}
can_notarize=false
if [ -n "${MACOS_SIGN_IDENTITY:-}" ] && [ -n "${APPLE_ID:-}" ] && [ -n "${APPLE_TEAM_ID:-}" ] && [ -n "${APPLE_APP_PASSWORD:-}" ]; then
  can_notarize=true
  echo "Notarisiere die App ..."
  ditto -c -k --keepParent "$app" "$stage/notarize.zip"
  notarize "$stage/notarize.zip"
  xcrun stapler staple "$app"
  spctl --assess --type execute --verbose "$app"
fi

# Update-Paket (die App mit angeheftetem Ticket).
ditto -c -k --keepParent "$app" "$zip"

# Download: Abbild mit der App und einer Verknüpfung zu "Programme".
mkdir "$stage/dmg"
ditto "$app" "$stage/dmg/Jellyflex.app"
ln -s /Applications "$stage/dmg/Programme"
hdiutil create -volname "Jellyflex" -srcfolder "$stage/dmg" -ov -format UDZO "$dmg" >/dev/null
if [ -n "${MACOS_SIGN_IDENTITY:-}" ]; then
  codesign --force --timestamp --sign "$MACOS_SIGN_IDENTITY" "$dmg"
fi
if $can_notarize; then
  echo "Notarisiere das Abbild ..."
  notarize "$dmg"
  xcrun stapler staple "$dmg"
fi

# Update-Paket signieren (für "Laden & installieren" in der App) und gegenprüfen.
key_file="$HOME/Library/Application Support/JellyflexRelease/update_signing_key.json"
if [ -n "${JELLYFLEX_UPDATE_SIGNING_KEY:-}" ] || [ -f "$key_file" ]; then
  dart run tool/sign_update.dart "$zip"
  flutter test test/update_key_check.dart "--dart-define=SIGNED=$zip"
else
  echo "Warnung: Kein Signaturschlüssel – die App kann dieses Update nicht selbst installieren." >&2
fi

echo "Fertig: $dmg und $zip"
