# ⚙️ Beschreibung der Parameter in `config.py`

Die Datei `config.py` definiert alle zentralen Pfade und Einstellungen,  
die von der Flask-Webanwendung der Root-CA genutzt werden.  
Sie liest Variablen aus der Datei `config.env` ein und stellt sie über die `Config`-Klasse bereit.

---

## 🧩 Allgemeine Struktur

```python
import os
from dotenv import load_dotenv

# Lädt Variablen aus config.env
load_dotenv(os.path.join(os.path.dirname(__file__), "config.env"))
```
Diese Zeilen laden die `.env`-Datei automatisch beim Start.  
Damit stehen alle dort definierten Variablen im Python-Programm als Umgebungsvariablen zur Verfügung.

---

## 🧱 Klassenbeschreibung: `Config`

Die Klasse `Config` stellt zentrale Parameter und Pfade als statische Variablen bereit,  
die in der Flask-App über `app.config.from_object(Config)` eingebunden werden.

---

## 🔑 Sicherheitsparameter

| Variable | Beschreibung |
|-----------|--------------|
| `SECRET_KEY` | Geheimschlüssel für Flask (z. B. für Login-Sessions). Wenn keine Umgebungsvariable gesetzt ist, wird der Standardwert `"devsecret"` verwendet. |

---

## 📁 Basisverzeichnisse

| Variable | Beschreibung |
|-----------|--------------|
| `BASE_DIR` | Basisverzeichnis der gesamten Root-CA-Struktur. Wird aus `config.env` gelesen oder fällt zurück auf `~/my-root-ca`. |
| `CA_DIR` | Enthält die eigentliche Root-CA-Struktur (inkl. privater Schlüssel, CRL und Zertifikate). |
| `ISSUED_DIR` | Verzeichnis mit allen ausgestellten (aktiven) Zertifikaten. |
| `ARCHIVE_DIR` | Unterordner von `issued`, in dem widerrufene oder abgelaufene Zertifikate archiviert werden. |
| `PASSWD_FILE` | Pfad zur Datei, die den verschlüsselten Hash des Web-Admin-Passworts speichert. |
| `DOCS_DIR` | Verzeichnis mit Markdown-Dokumentationen, die im Web-Interface angezeigt werden. |

---

## 🧾 Skriptpfade (CA-Verwaltung)

| Variable | Beschreibung |
|-----------|--------------|
| `CA_SCRIPTS_DIR` | Verzeichnis mit Shell-Skripten zur Zertifikatsverwaltung. |
| `ISSUE_SCRIPT` | Skript zur Erstellung eines neuen Server-Zertifikats (`issue_server_cert.sh`). |
| `REVOKE_SCRIPT` | Skript zum Widerrufen eines bestehenden Zertifikats (`revoke_cert.sh`). |
| `RENEW_SCRIPT` | Skript zur Erneuerung eines bestehenden Zertifikats (`renew_cert.sh`). |

Diese Skripte werden von der Webanwendung über `subprocess.run()` aufgerufen.  
Die Pfade können bei Bedarf angepasst werden, falls die Skripte an einem anderen Ort liegen.

---

## 📜 Root-Zertifikat

| Variable | Beschreibung |
|-----------|--------------|
| `CA_CERT_FILE` | Pfad zur öffentlichen Root-CA-Zertifikatsdatei (`ca.cert.pem`), die für den Client-Import bereitgestellt wird. |

---

## ⚡ Benutzeroberfläche (UI)

| Variable | Beschreibung |
|-----------|--------------|
| `ALERT_TIMEOUT_MS` | Zeit in Millisekunden, wie lange Flash-Nachrichten in der Weboberfläche sichtbar bleiben (z. B. 5000 ms = 5 Sekunden). |

---

## 🌐 Flask-Servereinstellungen

| Variable | Beschreibung |
|-----------|--------------|
| `FLASK_HOST` | IP-Adresse oder Hostname, auf dem der Flask-Server läuft. Standard: `0.0.0.0` (alle Interfaces). |
| `FLASK_PORT` | TCP-Port, auf dem der Server erreichbar ist (Standard: 5001). |
| `FLASK_DEBUG` | Aktiviert oder deaktiviert den Debug-Modus von Flask (True = Debug aktiv). |

---

## 🔍 Hinweise

- Alle Pfade basieren auf `BASE_DIR`, sodass du beim Verschieben des Projekts nur diesen Wert ändern musst.  
- Änderungen an Pfaden oder Ports erfordern ggf. einen Neustart der Anwendung.  
- Der `SECRET_KEY` sollte in der Produktion **immer** individuell gesetzt werden.