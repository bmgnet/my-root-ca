#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# issue_server_cert.sh - Server-Zertifikat mit SANs und neuem Schlüssel ausstellen
# -----------------------------------------------------------------------------
# - Generiert immer einen NEUEN Schlüssel und CSR.
# - CN wird immer als SAN:DNS hinzugefügt und Duplikate werden entfernt.
# - Erzeugt: key, csr, cert, fullchain, p12 (Passwort = YYYYMMDD).
# =============================================================================

# --- Konfiguration ---

# Lade zentrale Konfiguration
CONFIG_FILE="$(dirname "$0")/../config.env"
if [[ -f "$CONFIG_FILE" ]]; then
  source "$CONFIG_FILE"
else
  echo "❌ Konfigurationsdatei $CONFIG_FILE nicht gefunden!" >&2
  exit 1
fi

#DAYS=825             # ~27 Monate
#KEY_BITS=4096        # Standard auf 4096 Bits erhöht (wie in openssl.cnf req-Sektion)
#KEY_ALGO="rsa"       # Kann auf "ed25519" oder "rsa" gesetzt werden
# ---------------------

# --- CERT Sicherheit ---
#CERT_DAYS=825             # ~27 Monate
#CERT_KEY_BITS=4096        # Standard auf 4096 Bits erhöht (wie in openssl.cnf req-Sektion)
#CERT_KEY_ALGO="rsa"       # Kann auf "ed25519" oder "rsa" gesetzt werden

usage() {
  cat <<USAGE
Usage: $0 -c <commonName> [-d <dnsSAN> ...] [-i <ipSAN> ...] [-D <days>] [-o <outdir>] [-k <keybits>]

Beispiele:
  $0 -c pi-hole.bmgnet.loc
  $0 -c web01.bmgnet.loc -d web01.bmgnet.loc -d web01.test-lab.local -i 192.168.1.10
USAGE
  exit 1
}

# ------------------------------ Globale Variablen ------------------------------
CN=""
declare -a DNS_SANS
declare -a IP_SANS

# ------------------------------ Argumente parsen -------------------------------
while getopts ":c:d:i:D:o:k:" opt; do
  case "$opt" in
    c) CN="$OPTARG" ;;
    d) DNS_SANS+=("$OPTARG") ;;
    i) IP_SANS+=("$OPTARG") ;;
    D) CERT_DAYS="$OPTARG" ;;
    o) ISSUED_DIR="$OPTARG" ;;
    k) CERT_KEY_BITS="$OPTARG" ;;
    \?) echo "Fehler: Ungültige Option -$OPTARG" >&2; usage ;;
    :) echo "Fehler: Option -$OPTARG benötigt ein Argument." >&2; usage ;;
  esac
done

[[ -z "$CN" ]] && usage

mkdir -p "${ISSUED_DIR}"

# -------------------------- Temporäre Datei erstellen und TRAP setzen -------------------------
# Nutze mktemp -t, um sicherzustellen, dass die Datei im /tmp-Verzeichnis des Systems liegt
EXTFILE=$(mktemp -t openssl_exts_XXXXXXXX)
# Stellt sicher, dass die temporäre Datei beim Exit, egal ob Fehler oder Erfolg, gelöscht wird.
trap 'rm -f "${EXTFILE}"' EXIT
#echo "${EXTFILE}"

# --------------------------- Timestamp + Namen --------------------------------
STAMP="$(date +%Y%m%d%H%M%S)"
DATEPASS="${STAMP:0:8}"    # p12-Passwort = YYYYMMDD
# Filename-Basis: CN_YYYYMMDDHHMMSS
# Ersetze alle Nicht-Alphanumerischen Zeichen außer Bindestrich/Punkt mit Unterstrich für sauberen Filenamen
BASENAME="$(echo "${CN}" | tr -c '[:alnum:].-' '_')_${STAMP}"

KEY="${ISSUED_DIR}/${BASENAME}.key.pem"
CSR="${ISSUED_DIR}/${BASENAME}.csr.pem"
CERT="${ISSUED_DIR}/${BASENAME}.cert.pem"
CHAIN="${ISSUED_DIR}/${BASENAME}.fullchain.pem"
P12="${ISSUED_DIR}/${BASENAME}.p12"

# --------------------------- SAN-Liste aufbauen -------------------------------

# --------------------------- SAN-Liste aufbauen (BASH 3.x SAFE) -------------------------------

# CN immer als SAN:DNS hinzufügen
# DNS_SANS enthält jetzt alle über -d und den CN übergebenen DNS-Namen.
DNS_SANS=( "$CN" "${DNS_SANS[@]:-}" )

# 1. Deduplizierung in einem temporären String (robustere Methode für Bash 3.x)
DNS_LIST_STRING=""
# Wir verwenden printf, sort -u und grep -v, um die bereinigten Einträge zu erhalten.
DNS_LIST_STRING="$(printf "%s\n" "${DNS_SANS[@]:-}" | sort -u | grep -v '^$')"

# 2. Die bereinigten DNS-Namen in ein neues Array laden
# Das ist notwendig, um in der For-Schleife idx=1, 2, 3 zu erzeugen
DNS_SANS_FINAL=()
if [[ -n "$DNS_LIST_STRING" ]]; then
  # IFS=$'\n' liest Zeile für Zeile. Dies ist die kompatibelste Methode in Bash 3.x.
  while IFS= read -r line; do
    DNS_SANS_FINAL+=("$line")
  done <<< "$DNS_LIST_STRING"
fi

# ACHTUNG: Nur fortfahren, wenn IP_SANS nicht leer ist (set -u Schutz)
# Wenn das Array leer ist, wird der gesamte Block übersprungen.
#if [[ ${#IP_SANS[@]} -gt 0 ]]; then
  
  # Führende Leerzeichen entfernen
#  IP_SANS=("${IP_SANS[@]#[[:space:]]}") 
  
  # Nachfolgende Leerzeichen entfernen
#  IP_SANS=("${IP_SANS[@]%[[:space:]]}") 
  
  # Entfernt leere Elemente (aus den vorherigen Schritten)
#  IP_SANS=("${IP_SANS[@]:+${IP_SANS[@]}}") 
#fi

# Nur nicht-leere IPs übernehmen (Bereinigung beibehalten)
IP_SANS_FINAL=("${IP_SANS[@]:-}")
IP_SANS_FINAL=("${IP_SANS_FINAL[@]#[[:space:]]}")
IP_SANS_FINAL=("${IP_SANS_FINAL[@]%[[:space:]]}")
IP_SANS_FINAL=("${IP_SANS_FINAL[@]:+${IP_SANS_FINAL[@]}}")

# -------------------------- Extensions-Datei bauen ----------------------------
idx=1
# Wir erstellen die Datei mit einem Here Document (cat <<EOF), was die stabilste
# Methode für komplexe mehrzeilige Inhalte in Shells ist.
cat <<EOF > "${EXTFILE}"
[v3_server]
basicConstraints = CA:false
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer

subjectAltName = @alt_names

[alt_names]
EOF

# DNS SANS zur Datei hinzufügen
for d in "${DNS_SANS_FINAL[@]}"; do
  echo "DNS.${idx} = ${d}" >> "${EXTFILE}"
  idx=$((idx+1))
done

# IP SANS zur Datei hinzufügen (startet nach DNS-Einträgen)
for ip in "${IP_SANS_FINAL[@]}"; do
  if [[ -n "$ip" ]]; then
    echo "IP.${idx} = ${ip}" >> "${EXTFILE}"
    idx=$((idx+1))
  fi
done

# ------------------------------- Erstellung -----------------------------------
echo "==> Generiere Server-Key (${CERT_KEY_ALGO}:${CERT_KEY_BITS}): ${KEY}"
# Verwende genpkey für modernere Schlüsselerzeugung
if [[ "$CERT_KEY_ALGO" == "rsa" ]]; then
  openssl genpkey -algorithm RSA -out "${KEY}" -pkeyopt rsa_keygen_bits:"${CERT_KEY_BITS}" >/dev/null 2>&1
else
  # Für z.B. Ed25519 (KEINE KEY_BITS nötig)
  openssl genpkey -algorithm "${CERT_KEY_ALGO}" -out "${KEY}" >/dev/null 2>&1
fi

echo "==> Erzeuge CSR: ${CSR}"
# Verwende -batch und -subj für nicht-interaktive Erstellung
openssl req -new -key "${KEY}" -out "${CSR}" -subj "/CN=${CN}" -batch >/dev/null 2>&1

echo "==> Signiere Zertifikat mit CA (${CERT_DAYS} Tage)"
openssl ca -batch \
  -config "${CA_CONF_FILE}" \
  -extensions v3_server \
  -extfile "${EXTFILE}" \
  -days "${CERT_DAYS}" -notext -md sha256 \
  -in "${CSR}" -out "${CERT}" \
  -passin file:"${CA_DIR}/private/ca.pass"

# ------------------------------ Fullchain bauen -------------------------------
echo "==> Baue Fullchain: ${CHAIN}"
cat "${CERT}" "${CA_DIR}/certs/ca.cert.pem" > "${CHAIN}"

# --------------------------- PKCS#12 (P12) bauen ------------------------------
echo "==> Erzeuge PKCS#12 (P12): ${P12} (Pass: ${DATEPASS})"
openssl pkcs12 -export \
  -inkey "${KEY}" \
  -in "${CERT}" \
  -certfile "${CA_DIR}/certs/ca.cert.pem" \
  -name "${CN}" \
  -out "${P12}" \
  -passout "pass:${DATEPASS}"

# ------------------------------- Output ---------------------------------------
echo
echo "==> Fertig."
echo "Key:        ${KEY}"
echo "CSR:        ${CSR}"
echo "Cert:       ${CERT}"
echo "Fullchain:  ${CHAIN}"
echo "P12:        ${P12}"
echo "P12-Pass:   ${DATEPASS}"
echo
echo "==> Zertifikatsinfo:"
openssl x509 -noout -subject -issuer -dates -in "${CERT}"
echo
echo "==> SANs:"

# Zeige nur den Inhalt des SAN-Blocks
#openssl x509 -in "${CERT}" -noout -text | awk '/Subject Alternative Name/{flag=1; next} /X509v3/{flag=0} flag'
#-ext subjectAltName
#openssl x509 -noout -subject -issuer -dates -ext subjectAltName -in "${CERT}"

#echo "${EXTFILE}"


