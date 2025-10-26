#!/usr/bin/env bash
set -euo pipefail

#CA_DIR="/Users/bernd/Documents/Workspace/my-root-ca/ca"
#ISSUED_DIR="/Users/bernd/Documents/Workspace/my-root-ca/issued"
CONFIG_FILE="$(dirname "$0")/../config.env"
if [[ -f "$CONFIG_FILE" ]]; then
  source "$CONFIG_FILE"
else
  echo "❌ Konfigurationsdatei $CONFIG_FILE nicht gefunden!" >&2
  exit 1
fi

# Farben
GREEN="\e[32m"; YELLOW="\e[33m"; RED="\e[31m"; BLUE="\e[34m"; RESET="\e[0m"

FILTER_STATUS=""
FILTER_CN=""
FILTER_SAN=""
DETAILS_CN=""

usage() {
  echo "Usage: $0 [--valid] [--expired] [--revoked] [--cn <name>] [--san <pattern>] [--details <CN>]"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --valid) FILTER_STATUS="V"; shift ;;
    --expired) FILTER_STATUS="E"; shift ;;
    --revoked) FILTER_STATUS="R"; shift ;;
    --cn) FILTER_CN="$2"; shift 2 ;;
    --san) FILTER_SAN="$2"; shift 2 ;;
    --details) DETAILS_CN="$2"; shift 2 ;;
    *) usage ;;
  esac
done

if [[ -n "$DETAILS_CN" ]]; then
  CERT=$(ls -1 $ISSUED_DIR/${DETAILS_CN}_*.cert.pem 2>/dev/null | head -n 1 || true)
  [[ -z "$CERT" ]] && { echo "❌ Kein Zertifikat gefunden für CN=$DETAILS_CN"; exit 1; }
  openssl x509 -in "$CERT" -noout -text
  exit 0
fi

printf "${BLUE}%-30s %-15s %-12s %-15s %-50s${RESET}\n" "CN" "Ablauf" "Status" "Serial" "SAN"
echo "------------------------------------------------------------------------------------------------------------------------------------"

while read -r line; do
  STATUS=$(echo "$line" | awk '{print $1}')
  EXPIRE=$(echo "$line" | awk '{print $2}')
  SERIAL=$(echo "$line" | awk '{print $3}')
  SUBJECT=$(echo "$line" | awk -F'/CN=' '{print $2}')
  [[ -z "$SUBJECT" ]] && continue

  [[ -n "$FILTER_STATUS" && "$STATUS" != "$FILTER_STATUS" ]] && continue
  [[ -n "$FILTER_CN" && "$SUBJECT" != *"$FILTER_CN"* ]] && continue

  CERT_FILE=$(ls -1 $ISSUED_DIR/${SUBJECT}_*.cert.pem 2>/dev/null | head -n 1 || true)
  [[ -z "$CERT_FILE" ]] && continue

  SAN=$(openssl x509 -in "$CERT_FILE" -noout -text | grep -A1 "Subject Alternative Name" | tail -n1 | sed 's/^[[:space:]]*//')
  [[ -n "$FILTER_SAN" && "$SAN" != *"$FILTER_SAN"* ]] && continue

  STATUS_TXT="UNKNOWN"; COLOR=$YELLOW
  case "$STATUS" in
    V) STATUS_TXT="VALID"; COLOR=$GREEN ;;
    E) STATUS_TXT="EXPIRED"; COLOR=$RED ;;
    R) STATUS_TXT="REVOKED"; COLOR=$RED ;;
  esac

  EXP_DATE="20${EXPIRE:0:2}-${EXPIRE:2:2}-${EXPIRE:4:2}"
  printf "${COLOR}%-30s %-15s %-12s %-15s %-50s${RESET}\n" "$SUBJECT" "$EXP_DATE" "$STATUS_TXT" "$SERIAL" "$SAN"

done < "$CA_DIR/index.txt"
