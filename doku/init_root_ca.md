
# 📜 Root-CA Initialisierungsskript (`init_root_ca.sh`)

## 1\. Übersicht

Das Skript `init_root_ca.sh` dient zur **vollautomatischen Initialisierung und Erstellung** einer neuen, internen Root Certificate Authority (CA) basierend auf OpenSSL.

### Kernfunktionen

  * Laden der Konfiguration aus `config.env`.
  * Anlegen der notwendigen CA-Verzeichnisstruktur.
  * Automatische Generierung einer CA-Passphrase Speicherung in `${CA_DIR}/private/ca.pass`.
  * Erstellung einer vollständigen, dynamischen OpenSSL-Konfigurationsdatei (`openssl.cnf`).
  * Generierung des privaten RSA-Root-CA-Schlüssels (4096 Bit, AES-256 verschlüsselt).
  * Erstellung und Selbstsignierung des Root-CA-Zertifikats (10 Jahre Gültigkeit).

-----

## 2\. Voraussetzungen

### 2.1. Externe Konfiguration (`config.env`)

Dieses Skript ist von der Existenz und dem Inhalt der Datei `config.env` abhängig, die sich ein Verzeichnis über dem Skriptpfad befinden muss (`../config.env`).

### Mindestinhalt von `config.env`


Die Datei **`config.env`** muss mindestens die folgenden Variablen enthalten:

| Variable | Beschreibung | Beispielwert |
| :--- | :--- | :--- |
| `BASE_DIR` | Basisverzeichnis des CA-Projekts. | `~/my-root-ca` |
| `CA_DIR` | Verzeichnis der CA-Struktur (Zertifikate, Schlüssel, CRL). | `~/my-root-ca/ca` |
| `ISSUED_DIR` | Verzeichnis für ausgestellte Zertifikate. | `~/my-root-ca/issued` |
| `ARCHIVE_DIR` | Archiv für widerrufene oder abgelaufene Zertifikate. | `~/my-root-ca/issued/archive` |
| `EXPORT_DIR` | Speicherort für exportierte CRLs (z. B. für Apache oder Webserver). | `~/my-root-ca/ca/apache-crl` |
| `CA_PASS_FILE` | Passwortdatei der Root-CA. | `~/my-root-ca/ca/private/ca.pass` |
| `CA_CONF_FILE` | OpenSSL-Konfigurationsdatei der Root-CA. | `~/my-root-ca/ca/openssl.cnf` |

---

## Identitätsinformationen der CA

| Variable | Beschreibung | Beispielwert |
| :--- | :--- | :--- |
| `CA_COUNTRY` | Ländercode (C). | `AT` |
| `CA_STATE` | Bundesland oder Staat (ST). | `Vienna` |
| `CA_LOCALITY` | Ort (L). | `Vienna` |
| `CA_ORG` | Organisation oder Firma (O). | `BMGNET` |
| `CA_COMMON_NAME` | Anzeigename der Root-CA (CN). | `BMGNET Internal Root CA` |
| `CA_EMAIL` | Kontakt-E-Mail der CA. | `ca-admin@bmgnet.loc` |

---

## CRL-Konfiguration

| Variable | Beschreibung | Beispielwert |
| :--- | :--- | :--- |
| `CA_CRL_URI` | Haupt-Download-URI der Certificate Revocation List (CRL). | `URI:http://my-root-ca.bmgnet.loc/crl/ca.crl` |
| `CA_CRL_URI2` | Alternative / Fallback-CRL-URI. | `URI:http://pki.bmgnet.loc/crl/ca.crl` |

---

## Sicherheitseinstellungen (CA-Ebene)

| Variable | Beschreibung | Beispielwert |
| :--- | :--- | :--- |
| `CA_KEY_BITS` | Schlüssellänge des Root-CA-Private-Keys (in Bit). | `4096` |
| `CA_VALID_DAYS` | Gültigkeitsdauer der Root-CA in Tagen. | `3650` *(≈ 10 Jahre)* |

---

## Sicherheitseinstellungen (Server-Zertifikate)

| Variable | Beschreibung | Beispielwert |
| :--- | :--- | :--- |
| `CERT_DAYS` | Gültigkeitsdauer ausgestellter Server-Zertifikate. | `825` *(≈ 27 Monate)* |
| `CERT_KEY_BITS` | Schlüssellänge der Server-Zertifikate. | `4096` |
| `CERT_KEY_ALGO` | Schlüsselalgorithmus (`rsa` oder `ed25519`). | `rsa` |

---

## 3\. Ausführung und Sicherheit

### 3.1. Ausführung

Starten Sie das Skript einfach über die Kommandozeile:

```bash
./init_root_ca.sh
```

### 3.2. Passwortsicherheit

  * Beim ersten Start werden Sie aufgefordert, eine **neue Passphrase** für den Root-CA-Schlüssel einzugeben.
  * Diese Passphrase wird **unverschlüsselt** in der Datei `${CA_PASS_FILE}` (Standard: `${CA_DIR}/private/ca.pass`) gespeichert.
  * Das Skript setzt die Berechtigungen für diese Datei automatisch auf **`chmod 600`**, was sicherstellt, dass nur der ausführende Benutzer Lese- und Schreibrechte hat.

> ⚠️ **Wichtiger Sicherheitshinweis:** Die Passphrase-Datei muss unbedingt vor unbefugtem Zugriff geschützt werden. Der gesamte `CA_DIR` sollte nur für den CA-Administrator zugänglich sein.

-----

## 4\. Generierte Komponenten

Nach erfolgreicher Ausführung erzeugt das Skript folgende Schlüsselkomponenten:

| Datei/Verzeichnis | Beschreibung |
| :--- | :--- |
| **`ca/private/ca.key.pem`** | Der **private Schlüssel** der Root CA (verschlüsselt mit der gespeicherten Passphrase). |
| **`ca/certs/ca.cert.pem`** | Das **selbstsignierte Zertifikat** der Root CA (zur Verteilung und Import in Trust Stores). |
| **`ca/private/ca.pass`** | Die **Passphrase** zum Entschlüsseln von `ca.key.pem`. |
| **`ca/openssl.cnf`** | Die für diese CA angepasste OpenSSL-Konfigurationsdatei. |
| **`ca/index.txt`** | Die leere Datenbankdatei für ausgestellte Zertifikate. |
| **`ca/serial`** | Startwert für die Seriennummer (1000). |
| **`ca/crl`** | Verzeichnis für die Certificate Revocation List (CRL). |
| **`issued/`** | Verzeichnis für zukünftig ausgestellte Zertifikate (ausgegeben über `issue_server_cert.sh` etc.). |

### OpenSSL-Konfiguration (`ca/openssl.cnf`)

Die generierte Konfigurationsdatei für die interne CA:

  * **`copy_extensions = copy`**: Ermöglicht es Signierskripten (wie `issue_server_cert.sh`), Erweiterungen (z.B. SANs) aus externen Dateien zu setzen, ohne dass die Hauptkonfiguration diese überschreibt.
  * **`v3_ca`**: Definiert die Root CA als CA mit `pathlen:0`.
  * **`v3_server`**: Definiert die Standarderweiterungen für ausgestellte Server-Zertifikate (diese Sektion wird von den Skripten als Basis verwendet).
  * **`crlDistributionPoints`**: Definiert den URI für die CRL, der später in ausgestellte Zertifikate eingebettet wird (aus der Variable `${CA_CRL_URI}`).