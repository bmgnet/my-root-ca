import os
import re
import subprocess
from datetime import datetime

def list_certificates(ca_dir, issued_dir, include_archive=False):
    """
    Liest Zertifikate aus dem issued-Verzeichnis (und optional dem Archiv)
    und liefert folgende Daten:
      - CN (Common Name)
      - Seriennummer
      - Status aus index.txt (V/E/R)
      - Erstellungsdatum (notBefore)
      - Ablaufdatum (notAfter)
      - SANs (subjectAltName)
    """
    index_file = os.path.join(ca_dir, "index.txt")
    status_map = {}

    # 🔹 Status aus index.txt einlesen (Serial → Status)
    if os.path.exists(index_file):
        with open(index_file, "r") as f:
            for line in f:
                parts = line.strip().split("\t")
                if len(parts) >= 4:
                    serial = parts[3].strip()
                    status = parts[0].strip()
                    if serial and status:
                        status_map[serial.lstrip("0").upper()] = status

    # 🔹 optional auch archivierte Zertifikate mit einbeziehen
    directories = [issued_dir]
    archive_dir = os.path.join(issued_dir, "archive")
    if include_archive and os.path.isdir(archive_dir):
        directories.append(archive_dir)

    certs = []

    for directory in directories:
        for f in sorted(os.listdir(directory), reverse=True):
            if not f.endswith(".cert.pem"):
                continue

            cert_path = os.path.join(directory, f)
            cn = "unknown"
            serial = "unknown"
            not_before = "unbekannt"
            not_after = "unbekannt"
            san_text = ""
            status = "unknown"

            try:
                # === Subject / CN ===
                subj = subprocess.check_output(
                    ["openssl", "x509", "-in", cert_path, "-noout", "-subject"],
                    text=True
                ).strip()
                match = re.search(r"CN\s*=?\s*([^/]+)", subj)
                if match:
                    cn = match.group(1).strip()

                # === Seriennummer ===
                serial = subprocess.check_output(
                    ["openssl", "x509", "-in", cert_path, "-noout", "-serial"],
                    text=True
                ).strip().replace("serial=", "").lstrip("0").upper()

                # === Erstellungsdatum (notBefore) ===
                nb_raw = subprocess.check_output(
                    ["openssl", "x509", "-in", cert_path, "-noout", "-startdate"],
                    text=True
                ).strip().replace("notBefore=", "")
                try:
                    nb_dt = datetime.strptime(nb_raw, "%b %d %H:%M:%S %Y GMT")
                    not_before = nb_dt.strftime("%Y-%m-%d %H:%M")
                except ValueError:
                    not_before = nb_raw

                # === Ablaufdatum (notAfter) ===
                na_raw = subprocess.check_output(
                    ["openssl", "x509", "-in", cert_path, "-noout", "-enddate"],
                    text=True
                ).strip().replace("notAfter=", "")
                try:
                    na_dt = datetime.strptime(na_raw, "%b %d %H:%M:%S %Y GMT")
                    not_after = na_dt.strftime("%Y-%m-%d %H:%M")
                except ValueError:
                    not_after = na_raw

                # === SANs (subjectAltName) ===
                try:
                    san_output = subprocess.check_output(
                        ["openssl", "x509", "-in", cert_path, "-noout", "-ext", "subjectAltName"],
                        text=True
                    )
                    san_text = (
                        san_output.replace("X509v3 Subject Alternative Name:", "")
                        .replace("\n", "")
                        .replace(",", ", ")
                        .strip()
                    )
                except subprocess.CalledProcessError:
                    san_text = "(keine SANs)"

            except subprocess.CalledProcessError:
                san_text = "(Fehler beim Lesen des Zertifikats)"

            # === Status bestimmen ===
            status = status_map.get(serial, "V")

            certs.append({
                "cn": cn,
                "status": status,
                "created": not_before,
                "expire": not_after,
                "serial": serial or "unknown",
                "san": san_text,
                "file": f,
                "source": "archive" if directory == archive_dir else "active"
            })

    return certs