### Zertifikate archivieren

Sobald Zertifikate abgelaufen oder widerrufen sind, können sie mit dem Skript  
`scripts/archive_cert.sh` automatisch ins Archiv verschoben werden.

```bash
bash scripts/archive_cert.sh
```

---

#### 🔍 Zweck

Das Skript überprüft alle ausgestellten Zertifikate im **`ISSUED_DIR`** und verschiebt:
- **abgelaufene (`E`)** oder **widerrufene (`R`)** Zertifikate automatisch ins Archiv (`ARCHIVE_DIR`)
- sowie alle Zertifikate, **die nicht mehr im `index.txt`** der CA gelistet sind.

Es sorgt damit für Ordnung in der aktiven Zertifikatsliste.

---

#### ⚙️ Ablauf im Detail

1. **Lädt zentrale Konfiguration (`config.env`)**
   - Enthält Pfade wie `CA_DIR`, `ISSUED_DIR`, `ARCHIVE_DIR`
   - Bricht mit Fehler ab, falls die Datei fehlt.

2. **Vorbereitung**
   - Erstellt bei Bedarf den Archiv-Ordner.
   - Loggt alle Aktionen nach `${CA_DIR}/cleanup.log`.
   - Liest die CA-Datenbank (`index.txt`) und erstellt eine temporäre Zuordnung:  
     → Seriennummer → Zertifikatsstatus (`V`, `R`, `E`)

3. **Überprüfung aller ausgestellten Zertifikate**
   - Iteriert über alle `*.cert.pem` Dateien im `ISSUED_DIR`.
   - Liest die Seriennummer des Zertifikats via `openssl x509 -noout -serial`.
   - Prüft anhand des `index.txt`-Status:
     - `V` → Zertifikat bleibt aktiv
     - `R` oder `E` → wird archiviert

   Alle zugehörigen Dateien (`.key.pem`, `.csr.pem`, `.fullchain.pem`, `.p12`) werden gemeinsam verschoben.

4. **Prüfung auf verwaiste Zertifikate**
   - Zertifikate, die **keinen Eintrag im `index.txt`** besitzen, werden ebenfalls archiviert.
   - Diese Situation kann auftreten, wenn Zertifikate manuell erzeugt oder alte Indexeinträge gelöscht wurden.

5. **Aufräumen**
   - Temporäre Status-Datei wird gelöscht.
   - Abschlussmeldung wird ins Log geschrieben.

---

#### 🧩 Verzeichnisstruktur nach der Archivierung

```
ca/
├── certs/
├── crl/
├── newcerts/
├── private/
├── issued/
│   └── active Zertifikate (*.pem, *.p12)
└── archive/
    └── archivierte Zertifikate (*.pem, *.p12)
```

---

#### 🪶 Beispielausgabe

```
📦 [E] Verschiebe web01.bmgnet.loc_20231012103000.* nach archive/
📦 [R] Verschiebe oldserver_20220805145500.* nach archive/
⚠️  testserver_20210101000000.* nicht im index.txt – verschiebe ins Archiv.
✅ Cleanup abgeschlossen: Sat Oct 25 12:45:10 2025
```

---

#### 💡 Hinweise

- Alle Aktionen werden in `${CA_DIR}/cleanup.log` protokolliert.
- Das Skript kann regelmäßig via **Cronjob** ausgeführt werden, z. B.:

```bash
0 2 * * 0 /path/to/scripts/archive_cert.sh
```

- Archivierte Zertifikate bleiben vollständig erhalten – sie werden **nicht gelöscht**.
- Der Index und die CA-Datenbank bleiben unverändert.

---
