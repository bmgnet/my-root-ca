#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# create_root_ca.sh - Erstellt die Root CA mit automatisch gespeicherter Passphrase
# -----------------------------------------------------------------------------
# - Speichert das Root-CA-Passwort sicher in ${CA_DIR}/private/ca.pass
# - Generiert Schlüssel, Zertifikat und OpenSSL-Konfiguration
# =============================================================================


CONFIG_FILE="$(dirname "$0")/../config.env"
if [[ -f "$CONFIG_FILE" ]]; then
  source "$CONFIG_FILE"
else
  echo "❌ Konfigurationsdatei $CONFIG_FILE nicht gefunden!" >&2
  exit 1
fi

umask 077

mkdir -p "${CA_DIR}"/{certs,newcerts,crl,private}
mkdir -p "${ISSUED_DIR}"
: > "${CA_DIR}/index.txt"
: > "${CA_DIR}/index.txt.attr"
echo 1000 > "${CA_DIR}/serial"
echo 1000 > "${CA_DIR}/crlnumber"

#CA_PASS_FILE="${CA_DIR}/private/ca.pass"
#CONF="${CA_DIR}/openssl.cnf"

# --------------------------- Passwortbehandlung ------------------------------
if [[ ! -f "$CA_PASS_FILE" ]]; then
  echo "🔐 Bitte ein neues Passwort für die Root-CA festlegen (wird in ${CA_PASS_FILE} gespeichert):"
  read -r -s CA_PASS
  echo
  echo "$CA_PASS" > "$CA_PASS_FILE"
  chmod 600 "$CA_PASS_FILE"
  echo "✅ Passwort wurde sicher gespeichert."
else
  echo "ℹ️  Passwortdatei ${CA_PASS_FILE} existiert bereits – wird verwendet."
  chmod 600 "$CA_PASS_FILE"
fi

# OpenSSL-Config schreiben (falls nicht vorhanden)
if [[ ! -f "${CA_CONF_FILE}" ]]; then
cat > "${CA_CONF_FILE}" <<EOF
[ ca ]
default_ca = CA_default

[ CA_default ]
dir               = ${CA_DIR}
certs             = \$dir/certs
crl_dir           = \$dir/crl
new_certs_dir     = \$dir/newcerts
database          = \$dir/index.txt
serial            = \$dir/serial
crlnumber         = \$dir/crlnumber
RANDFILE          = \$dir/private/.rand
unique_subject    = no

private_key       = \$dir/private/ca.key.pem
certificate       = \$dir/certs/ca.cert.pem

# Policy & Defaults
default_md        = sha256
default_days      = ${CA_VALID_DAYS}
preserve          = no
policy            = policy_loose
email_in_dn       = no
copy_extensions   = copy

# Ausgabeoptionen
name_opt          = ca_default
cert_opt          = ca_default

# CRL
crl               = \$dir/crl/ca.crl.pem
crl_extensions    = crl_ext
default_crl_days  = 30

[ policy_loose ]
countryName             = optional
stateOrProvinceName     = optional
localityName            = optional
organizationName        = optional
organizationalUnitName  = optional
commonName              = supplied
emailAddress            = optional

[ req ]
default_bits        = ${CA_KEY_BITS}
distinguished_name  = req_distinguished_name
x509_extensions     = v3_ca
string_mask         = utf8only
prompt              = no

[ req_distinguished_name ]
C  = ${CA_COUNTRY}
ST = ${CA_STATE}
L  = ${CA_LOCALITY}
O  = ${CA_ORG}
CN = ${CA_COMMON_NAME}
emailAddress = ${CA_EMAIL}

[ v3_ca ]
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:true, pathlen:0
keyUsage = critical, keyCertSign, cRLSign
crlDistributionPoints = @crl_section

[ v3_server ]
basicConstraints = CA:false
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
crlDistributionPoints = @crl_section

[ crl_section ]
URI.1 = ${CA_CRL_URI}
# optional 
# URI.2 = ${CA_CRL_URI2}

[ crl_ext ]
authorityKeyIdentifier=keyid:always
EOF

  # Pfad einsetzen
  #sed -i "s|REPLACE_ME|${CA_DIR}|g" "${CA_CONF_FILE}"
  echo "✅ OpenSSL-Konfiguration erstellt unter ${CA_CONF_FILE}"
else
  echo "ℹ️  OpenSSL-Konfiguration existiert bereits (${CA_CONF_FILE})"
fi

echo "==> CA-Verzeichnis: ${CA_DIR}"
echo "==> Generiere Root-CA-Schlüssel (AES-256 geschützt, Passphrase erbeten)..."
openssl genrsa -aes256 \
  -passout file:"${CA_PASS_FILE}" \
  -out "${CA_DIR}/private/ca.key.pem" 4096

echo "==> Erzeuge selbstsigniertes Root-CA-Zertifikat (10 Jahre)..."
openssl req -config "${CA_CONF_FILE}" \
  -key "${CA_DIR}/private/ca.key.pem" \
  -passin file:"${CA_PASS_FILE}" \
  -new -x509 -days 3650 -sha256 -extensions v3_ca \
  -out "${CA_DIR}/certs/ca.cert.pem"

# --------------------------- Ausgabe -----------------------------------------
echo "✅ Fertig. Root-CA-Zertifikat erstellt!"
echo "📄  Zertifikat: ${CA_DIR}/certs/ca.cert.pem"
echo "🔑  Schlüssel:   ${CA_DIR}/private/ca.key.pem"
echo "🔐  Passwort:   ${CA_PASS_FILE}"
echo
openssl x509 -noout -subject -issuer -dates -in "${CA_DIR}/certs/ca.cert.pem"


