# 🧭 Installation Guide — CA Admin Webinterface

## 🔧 Voraussetzungen

Diese Anleitung beschreibt die Installation **von Grund auf**:  
- Kein Python installiert  
- Kein OpenSSL vorhanden  
- Internetzugang vorhanden (zum Herunterladen von Paketen)

---

## 🐧 1. Installation auf **Ubuntu 24.04 LTS**

### 1.1 System aktualisieren
```bash
sudo apt update && sudo apt upgrade -y
```

### 1.2 Notwendige Pakete installieren
```bash
sudo apt install -y python3 python3-venv python3-pip openssl git
```

💡 Erklärung:
- `python3` → Python-Interpreter  
- `python3-venv` → virtuelle Python-Umgebungen  
- `python3-pip` → Paketverwaltung für Python  
- `openssl` → zur Zertifikatsverwaltung  
- `git` → optional zum Klonen deines Projekts

---

### 1.3 Projekt klonen oder kopieren
Falls dein Projekt z. B. in GitHub liegt:
```bash
git clone https://github.com/bmgnet/my-root-ca.git
cd my-root-ca-admin
```

Oder: kopiere dein Projektverzeichnis manuell auf den Rechner und gehe hinein:
```bash
cd my-root-ca-admin
```

---

### 1.4 Virtuelle python Umgebung anlegen
```bash
python3 -m venv venv
source venv/bin/activate
```

---

### 1.5 Python-Abhängigkeiten installieren

> Wichtig: Virtuelle python Umgebung venv muss laufen!
```bash
source venv/bin/activate
pip install -r requirements.txt
```

---

### 1.6 CA-Struktur initialisieren

Bevor Zertifikate ausgestellt werden können, muss die Root Certificate Authority (CA) eingerichtet werden.  
Dies erfolgt über das Skript `init_root_ca.sh`.

```bash
cd my-root-ca-admin
./ca_tools_bash/init_root_ca.sh
```

#### 🔍 Funktionsbeschreibung

Das Skript erstellt **alle benötigten Verzeichnisse, Konfigurationsdateien und Schlüssel** für eine neue Root-CA.

**Im Detail:**

1. **Lädt `config.env`**  
   Alle Parameter (z. B. CA-Pfade, Gültigkeitsdauer, Distinguished Name) werden aus der Datei `config.env` eingelesen.  
   Fehlt die Datei, wird das Skript mit einer Fehlermeldung abgebrochen.

2. **Erstellt die CA-Verzeichnisstruktur**  
   Legt die folgenden Ordner an:
   ```
   ca/
   ├── certs/        # CA-Zertifikate
   ├── crl/          # Widerrufslisten
   ├── newcerts/     # neu ausgestellte Zertifikate
   ├── private/      # privater Schlüssel (geschützt)
   ├── issued/       # signierte Zertifikate
   └── archive/      # archivierte Zertifikate
   ```
   Außerdem werden `index.txt`, `serial`, und `crlnumber` initialisiert.

3. **Behandelt die Passwortdatei (`ca.pass`)**  
   - Falls noch kein Passwort existiert, fragt das Skript interaktiv nach einem neuen Root-CA-Passwort.  
   - Dieses wird verschlüsselt und sicher in `${CA_DIR}/private/ca.pass` gespeichert (chmod 600).  
   - Bei erneutem Aufruf wird das bestehende Passwort weiterverwendet.

4. **Erzeugt automatisch eine OpenSSL-Konfigurationsdatei**  
   Die Datei `${CA_CONF_FILE}` enthält vordefinierte Sektionen für:
   - Root-CA-Zertifikate (`v3_ca`)
   - Server-Zertifikate (`v3_server`)
   - Widerrufslisten (`crl_ext`)
   - Pfade, Policies und Gültigkeitsregeln  
   
   Die Werte (z. B. Organisation, CN, Gültigkeitsdauer) werden aus `config.env` übernommen.

5. **Generiert den Root-CA-Schlüssel und das Zertifikat**
   - Erstellt einen **4096-bit RSA-Schlüssel** (`ca.key.pem`), AES-256-verschlüsselt.  
   - Generiert ein **selbstsigniertes Root-CA-Zertifikat** (`ca.cert.pem`) mit 10 Jahren Gültigkeit.  
   - Nutzt die zuvor erstellte OpenSSL-Konfiguration.

6. **Gibt am Ende eine Zusammenfassung aus**
   ```
   ✅ Fertig. Root-CA-Zertifikat erstellt!
   📄 Zertifikat: ca/certs/ca.cert.pem
   🔑 Schlüssel:  ca/private/ca.key.pem
   🔐 Passwort:   ca/private/ca.pass
   ```

💡 **Hinweis:**  
Das Skript ist **idempotent** – falls bereits eine CA existiert, werden vorhandene Dateien erkannt und nicht überschrieben.  
Die OpenSSL-Konfiguration und das Passwort werden bei Bedarf wiederverwendet.

---

### 1.7 Anwendung starten
```bash
source venv/bin/activate
python app.py
```

💡 Standardmäßig läuft der Server auf:  
👉 http://127.0.0.1:5001

---

## 🍎 2. Installation auf **macOS Sequoia (Version 15 / macOS 26)**

### 2.1 Homebrew installieren (falls nicht vorhanden)
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Nach der Installation:
```bash
brew update
```

---

### 2.2 Python 3 und OpenSSL installieren
```bash
brew install python openssl git
```

Prüfen:
```bash
python3 --version
openssl version
```

---

### 2.3 Download my root ca
```bash
git clone https://github.com/bmgnet/my-root-ca.git
cd my-root-ca-admin
```

---

### 2.4 Virtuelle Umgebung erstellen
```bash
python3 -m venv venv
source venv/bin/activate
```

---

### 2.5 Abhängigkeiten installieren
```bash
pip install -r requirements.txt
```

---

### 2.6 CA-Struktur initialisieren

Bevor Zertifikate ausgestellt werden können, muss die Root Certificate Authority (CA) eingerichtet werden.  
Dies erfolgt über das Skript `init_root_ca.sh`.

```bash
cd my-root-ca-admin
./ca_tools_bash/init_root_ca.sh
```

---

### 2.7 Anwendung starten
```bash
source venv/bin/activate
python app.py
```

Danach erreichst du die Anwendung unter:  
👉 http://127.0.0.1:5001

---

## ⚙️ 3. Optional: automatischer Start (Linux only)

Wenn du den Dienst z. B. dauerhaft laufen lassen willst (Headless-Modus):

### Datei `/etc/systemd/system/ca-admin.service`
```ini
[Unit]
Description=CA Admin Flask Webapp
After=network.target

[Service]
User=caadmin
WorkingDirectory=/opt/my-root-ca-admin
ExecStart=~/my-root-ca-admin/venv/bin/python ~/my-root-ca-admin/app.py
Restart=always

[Install]
WantedBy=multi-user.target
```

Aktivieren und starten:
```bash
sudo systemctl daemon-reload
sudo systemctl enable ca-admin
sudo systemctl start ca-admin
```
