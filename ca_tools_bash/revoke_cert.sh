#!/usr/bin/env bash
set -euo pipefail

# Lade zentrale Konfiguration
CONFIG_FILE="$(dirname "$0")/../config.env"
if [[ -f "$CONFIG_FILE" ]]; then
  source "$CONFIG_FILE"
else
  echo "❌ Konfigurationsdatei $CONFIG_FILE nicht gefunden!" >&2
  exit 1
fi

#CA_DIR="${HOME}/my-root-ca/ca"
#ISSUED_DIR="${HOME}/my-root-ca/issued"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <Zertifikat-Datei oder CommonName>"
  echo "Beispiel:"
  echo "  $0 pi-hole.bmgnet.loc"
  echo "  $0 pi-hole.bmgnet.loc_20250118.cert.pem"
  exit 1
fi

TARGET="$1"
CERT_FILE=""

# Falls direkt Datei angegeben wurde
if [[ -f "${TARGET}" ]]; then
  CERT_FILE="${TARGET}"
# Falls nach CN gesucht werden soll
elif [[ -f "${ISSUED_DIR}/${TARGET}" ]]; then
  CERT_FILE="${ISSUED_DIR}/${TARGET}"
else
  # Automatisch Zertifikat suchen
  CERT_FILE=$(find "${ISSUED_DIR}" -maxdepth 1 -name "*${TARGET}*.cert.pem" | head -n 1 || true)
fi

if [[ -z "${CERT_FILE}" ]]; then
  echo "❌ Zertifikat nicht gefunden für: $TARGET"
  exit 1
fi

echo "🔎 Zertifikat gefunden: ${CERT_FILE}"
echo "🚨 Widerrufe Zertifikat..."
openssl ca -config "${CA_CONF_FILE}" -revoke "${CERT_FILE}"

echo "📜 Erzeuge neue CRL (Certificate Revocation List)..."
openssl ca -config "${CA_CONF_FILE}" -gencrl -out "${CA_DIR}/crl/ca.crl.pem"

echo "✅ Zertifikat widerrufen!"
echo "👉 Widerrufene Zertifikate stehen in: ${CA_DIR}/index.txt"
echo "👉 Aktualisierte CRL: ${CA_DIR}/crl/ca.crl.pem"
