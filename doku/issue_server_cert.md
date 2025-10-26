### Server-Zertifikat ausstellen per Script

Sobald die Root-CA erstellt ist, können Server-Zertifikate über das Skript  
`scripts/issue_server_cert.sh` generiert werden.

```bash
bash scripts/issue_server_cert.sh -c <CommonName> [-d <DNS>] [-i <IP>] ...
```

**Beispiele:**
```bash
# Einfaches Zertifikat
bash scripts/issue_server_cert.sh -c pi-hole.bmgnet.loc

# Mit mehreren SANs (DNS + IP)
bash scripts/issue_server_cert.sh -c web01.bmgnet.loc -d web01.test-lab.local -i 192.168.1.10
```

---

#### 🔍 Funktionsbeschreibung

Dieses Skript erstellt **automatisch ein neues Server-Zertifikat**, inklusive:

- privatem Schlüssel (`.key.pem`)
- Certificate Signing Request (`.csr.pem`)
- signiertem Zertifikat (`.cert.pem`)
- Zertifikatskette (`.fullchain.pem`)
- PKCS#12-Container (`.p12`) mit Tagesdatum als Passwort (`YYYYMMDD`)

---

#### ⚙️ Ablauf im Detail

1. **Lädt die zentrale `config.env`**
   - Enthält Pfade (`CA_DIR`, `ISSUED_DIR`), Gültigkeitsdauer, Schlüsselgröße, usw.
   - Wird die Datei nicht gefunden, bricht das Skript mit einem Fehler ab.

2. **Parst die Befehlszeilenargumente**
   - `-c` → Common Name (Pflicht)
   - `-d` → zusätzliche DNS-SANs (mehrfach möglich)
   - `-i` → IP-Adressen als SANs (mehrfach möglich)
   - `-D` → Gültigkeitsdauer in Tagen (optional)
   - `-o` → Ausgabeordner (optional)
   - `-k` → Schlüssellänge (optional)

   Beispiel:
   ```bash
   ./issue_server_cert.sh -c server1.local -d server1 -d server1.domain.tld -i 10.0.0.5
   ```

3. **Erstellt sichere Dateinamen und Verzeichnisse**
   - Ausgabe liegt standardmäßig in `${ISSUED_DIR}`.
   - Basisname enthält CN + Zeitstempel (`YYYYMMDDHHMMSS`).
   - Beispiel:
     ```
     server1.local_20251025120000.cert.pem
     server1.local_20251025120000.key.pem
     ```

4. **Generiert dynamische SAN-Liste**
   - CN wird immer automatisch als `DNS`-SAN hinzugefügt.
   - Duplikate werden entfernt.
   - IP-Adressen werden separat eingetragen.
   - Die resultierende Erweiterungsdatei (`/tmp/openssl_exts_XXXXXX`) enthält:
     ```
     [v3_server]
     basicConstraints = CA:false
     keyUsage = critical, digitalSignature, keyEncipherment
     extendedKeyUsage = serverAuth
     subjectAltName = @alt_names

     [alt_names]
     DNS.1 = server1.local
     DNS.2 = web01.test-lab.local
     IP.3  = 192.168.1.10
     ```

5. **Erzeugt den privaten Schlüssel**
   - Standard: RSA 4096 Bit (`openssl genpkey`)
   - Alternativ: ed25519 (per `config.env` konfigurierbar)

6. **Erstellt den CSR (Certificate Signing Request)**
   - Automatisch, ohne interaktive Eingabe.
   - Enthält Subject und CN.

7. **Signiert das Zertifikat mit der Root-CA**
   - Nutzt `${CA_DIR}/openssl.cnf` und `ca.pass`.
   - Erweiterungen und SANs stammen aus der temporären Datei.
   - Standardgültigkeit: 825 Tage (~27 Monate).

8. **Erstellt die Fullchain**
   - Fasst das Serverzertifikat und das Root-CA-Zertifikat zusammen:
     ```bash
     cat server.cert.pem ca.cert.pem > fullchain.pem
     ```

9. **Erzeugt ein PKCS#12-Paket (`.p12`)**
   - Enthält Schlüssel, Zertifikat und CA-Zertifikat.
   - Passwort = aktuelles Datum (`YYYYMMDD`).

10. **Zeigt am Ende eine Zusammenfassung**
    ```
    ✅ Fertig.
    Key:        issued/server1_20251025120000.key.pem
    Cert:       issued/server1_20251025120000.cert.pem
    Fullchain:  issued/server1_20251025120000.fullchain.pem
    P12:        issued/server1_20251025120000.p12
    P12-Pass:   20251025
    ```

---

#### 🧩 Ausgabeübersicht

| Datei | Beschreibung |
|-------|---------------|
| `*.key.pem` | Privater Schlüssel |
| `*.csr.pem` | Certificate Signing Request |
| `*.cert.pem` | Signiertes Serverzertifikat |
| `*.fullchain.pem` | Zertifikat + CA |
| `*.p12` | PKCS#12-Container (inkl. Key & Chain) |

---

#### 💡 Hinweise

- Alle Zertifikate werden automatisch im `ISSUED_DIR` gespeichert.
- Die CN wird **immer** als SAN eingetragen (auch ohne `-d`).
- Das Skript löscht temporäre Dateien automatisch nach Abschluss.
- Unterstützt Bash 3.x (kompatibel zu macOS & Linux).
