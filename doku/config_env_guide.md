### 🛠️ Anleitung zur Konfiguration der Datei `config.env`

Die Datei `config.env` enthält alle zentralen Pfadangaben und Parameter für deine Root-CA-Verwaltung.  
Sie wird von der Python-App beim Start automatisch eingelesen und steuert, wo Zertifikate, Schlüssel und Konfigurationsdateien gespeichert werden.

---

## 📄 1. Erstellung der Datei

Kopiere die Beispiel-Datei `config.env.example` nach `config.env`:

```bash
cp config.env.example config.env
```

Danach bearbeite `config.env` mit einem Texteditor (z. B. VS Code, nano oder vim)  
und passe die Pfade sowie CA-Informationen an dein System an.

---

## ⚙️ 2. Beispielkonfiguration

Nachfolgend eine vollständige, funktionierende Beispiel-`config.env`:

```bash
# =====================================================================
# Root CA zentrale Konfiguration
# =====================================================================

# --- Basisverzeichnisse ---
BASE_DIR="~/my-root-ca"
CA_DIR="~/my-root-ca/ca"
ISSUED_DIR="~/my-root-ca/issued"
ARCHIVE_DIR="~/my-root-ca/issued/archive"
EXPORT_DIR="~/my-root-ca/ca/apache-crl" # Speicherort für Apache CRL
CA_PASS_FILE="~/my-root-ca/ca/private/ca.pass"
CA_CONF_FILE="~/my-root-ca/openssl.cnf"

# --- CA Identität ---
CA_COUNTRY="AT"
CA_STATE="Vienna"
CA_LOCALITY="Vienna"
CA_ORG="BMGNET"
CA_COMMON_NAME="BMGNET Internal Root CA"
CA_EMAIL="ca-admin@bmgnet.loc"

# --- CA Zertifikat Erweiterung ---
CA_CRL_URI="URI:http://my-root-ca.bmgnet.loc/crl/ca.crl"
CA_CRL_URI2="URI:http://pki.bmgnet.loc/crl/ca.crl"

# --- Sicherheit ---
CA_KEY_BITS=4096
CA_VALID_DAYS=3650

# --- CERT Sicherheit ---
CERT_DAYS=825             # ~27 Monate
CERT_KEY_BITS=4096        # Standard auf 4096 Bits erhöht (wie in openssl.cnf req-Sektion)
CERT_KEY_ALGO="rsa"       # Kann auf "ed25519" oder "rsa" gesetzt werden
```

---

## 📁 3. Erklärung der wichtigsten Abschnitte

### 🧩 Basisverzeichnisse

| Variable        | Beschreibung |
|-----------------|---------------|
| `BASE_DIR`      | Hauptverzeichnis deiner Root-CA-Umgebung |
| `CA_DIR`        | Pfad zur CA-Struktur mit privaten Schlüsseln und Zertifikaten |
| `ISSUED_DIR`    | Verzeichnis für ausgestellte Zertifikate |
| `ARCHIVE_DIR`   | Ablageort für widerrufene oder abgelaufene Zertifikate |
| `EXPORT_DIR`    | Ort, an dem die CA-CRL (Certificate Revocation List) exportiert wird |
| `CA_PASS_FILE`  | Passwortdatei der CA (wird von OpenSSL genutzt) |
| `CA_CONF_FILE`  | OpenSSL-Konfigurationsdatei der Root-CA |

---

### 🏢 CA-Identität

Diese Angaben werden im Root-CA-Zertifikat und in ausgestellten Zertifikaten verwendet.

| Variable | Bedeutung |
|-----------|------------|
| `CA_COUNTRY` | Ländercode (z. B. "AT") |
| `CA_STATE` | Bundesland / Staat |
| `CA_LOCALITY` | Ort |
| `CA_ORG` | Organisation / Firma |
| `CA_COMMON_NAME` | Anzeigename der Root-CA |
| `CA_EMAIL` | Kontaktadresse der CA |

---

### 🔗 CRL (Certificate Revocation List)

URLs, unter denen Clients oder Browser die Sperrliste abrufen können.

| Variable | Beschreibung |
|-----------|--------------|
| `CA_CRL_URI`  | Öffentliche CRL-URL (z. B. interner Server) |
| `CA_CRL_URI2` | Zweite CRL-URL (z. B. über externen Fallback-Server) |

---

### 🔐 Sicherheitseinstellungen

| Variable | Beschreibung |
|-----------|--------------|
| `CA_KEY_BITS`   | Schlüssellänge des CA-Schlüssels (empfohlen: 4096 Bit) |
| `CA_VALID_DAYS` | Gültigkeitsdauer der CA in Tagen (z. B. 3650 = 10 Jahre) |

---

### 📜 Zertifikats-Sicherheit

| Variable | Beschreibung |
|-----------|--------------|
| `CERT_DAYS`     | Standard-Gültigkeitsdauer für neue Zertifikate (~27 Monate = 825 Tage) |
| `CERT_KEY_BITS` | Schlüssellänge für Server-Zertifikate |
| `CERT_KEY_ALGO` | Algorithmus („rsa“ oder „ed25519“) |

---

## ✅ 4. Tipps

- Verwende absolute Pfade (beginnend mit `/`), um Fehler zu vermeiden.  
- Die Datei `config.env` sollte **nicht** öffentlich zugänglich sein, da sie Pfade zu sensiblen Schlüsseln enthält.  
- Wenn du dein CA-Verzeichnis verschiebst, musst du die Pfade anpassen.    
- Achte darauf, dass Zeilen mit `#` als Kommentare behandelt werden.

---

## 🧩 5. Verbindung zur Anwendung

Beim Start der Web-App (`app.py`) wird `config.env` automatisch geladen über:
Die Werte stehen dann in Python als Umgebungsvariablen zur Verfügung.
