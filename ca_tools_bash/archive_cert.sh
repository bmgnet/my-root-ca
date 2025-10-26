#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="$(dirname "$0")/../config.env"
if [[ -f "$CONFIG_FILE" ]]; then
  source "$CONFIG_FILE"
else
  echo "❌ Konfigurationsdatei $CONFIG_FILE nicht gefunden!" >&2
  exit 1
fi

INDEX="$CA_DIR/index.txt"
LOGFILE="$CA_DIR/cleanup.log"

mkdir -p "$ARCHIVE_DIR"

echo "🧹 Cleanup gestartet: $(date)" >> "$LOGFILE"

# 1️⃣ Temporäre Datei mit Seriennummer → Status
TMP_STATUS=$(mktemp)
grep -E '^[VRE]' "$INDEX" | awk -F'\t' '{printf "%s %s\n", tolower($4), $1}' | sed 's/^0*//' > "$TMP_STATUS"

# 2️⃣ Alle Zertifikate im issued_dir prüfen
for cert in "$ISSUED_DIR"/*.cert.pem; do
  [[ -e "$cert" ]] || continue
  serial=$(openssl x509 -in "$cert" -noout -serial 2>/dev/null | cut -d= -f2 | tr '[:upper:]' '[:lower:]' | sed 's/^0*//')
  base="${cert%.cert.pem}"

  status=$(grep -m1 "^$serial " "$TMP_STATUS" | awk '{print $2}')

  if [[ "$status" == "R" || "$status" == "E" ]]; then
    echo "📦 [$status] Verschiebe $base.* nach $ARCHIVE_DIR" | tee -a "$LOGFILE"
    for ext in .cert.pem .key.pem .csr.pem .fullchain.pem .p12; do
      [[ -f "$base$ext" ]] && mv "$base$ext" "$ARCHIVE_DIR"/
    done
  fi
done

# 3️⃣ Alles verschieben, was keinen Index-Eintrag hat
echo "🔍 Prüfe Dateien ohne Seriennummer im index.txt" | tee -a "$LOGFILE"
for cert in "$ISSUED_DIR"/*.cert.pem; do
  [[ -e "$cert" ]] || continue
  serial=$(openssl x509 -in "$cert" -noout -serial 2>/dev/null | cut -d= -f2 | tr '[:upper:]' '[:lower:]' | sed 's/^0*//')
  if ! grep -q "^$serial " "$TMP_STATUS"; then
    base="${cert%.cert.pem}"
    echo "⚠️  $base.* nicht im index.txt – verschiebe ins Archiv." | tee -a "$LOGFILE"
    for ext in .cert.pem .key.pem .csr.pem .fullchain.pem .p12; do
      [[ -f "$base$ext" ]] && mv "$base$ext" "$ARCHIVE_DIR"/
    done
  fi
done

rm -f "$TMP_STATUS"
echo "✅ Cleanup abgeschlossen: $(date)" >> "$LOGFILE"