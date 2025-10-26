#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="$(dirname "$0")/../config.env"
if [[ -f "$CONFIG_FILE" ]]; then
  source "$CONFIG_FILE"
else
  echo "❌ Konfigurationsdatei $CONFIG_FILE nicht gefunden!" >&2
  exit 1
fi

#CA_DIR="${HOME}/my-root-ca/ca"
#EXPORT_DIR="${CA_DIR}/apache-crl" # Speicherort für Apache CRL – ändern falls nötig

# Export-Verzeichnis anlegen
mkdir -p "$EXPORT_DIR"

# Export-Verzeichnis anlegen
mkdir -p "$EXPORT_DIR"

echo "📜 Generiere neue CRL (Certificate Revocation List)..."
openssl ca -config "$CA_DIR/openssl.cnf" -gencrl -out "$CA_DIR/crl/ca.crl.pem" -passin file:"${CA_PASS_FILE}"

echo "🔁 Konvertiere CRL zu Apache kompatibler Version..."
openssl crl -in "$CA_DIR/crl/ca.crl.pem" -out "$CA_DIR/crl/ca.crl" -outform DER

echo "📦 Exportiere Dateien nach $EXPORT_DIR..."
cp "$CA_DIR/crl/ca.crl.pem" "$EXPORT_DIR/"
cp "$CA_DIR/crl/ca.crl" "$EXPORT_DIR/"

echo "✅ CRL erfolgreich exportiert!"
echo " -> PEM CRL: $EXPORT_DIR/ca.crl.pem"
echo " -> DER CRL (Apache): $EXPORT_DIR/ca.crl"
