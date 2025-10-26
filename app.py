from flask import Flask, render_template, redirect, url_for, request, flash, send_from_directory, abort
from flask_login import LoginManager, login_required, login_user, logout_user, UserMixin, current_user
import os
import bcrypt
from ca_tools.list_certs import list_certificates
from config import Config
import subprocess
import tempfile
from pathlib import Path
from markupsafe import Markup
import markdown2

app = Flask(__name__)
app.config.from_object(Config)

# --- Login Setup ---
login_manager = LoginManager(app)
login_manager.login_view = "login"

def load_password_hash(app) -> bytes:
    """Lädt den gespeicherten bcrypt-Hash aus der Datei oder erstellt ihn initial."""
    passwd_file = app.config["PASSWD_FILE"]
    os.makedirs(os.path.dirname(passwd_file), exist_ok=True)

    if os.path.exists(passwd_file):
        with open(passwd_file, "rb") as f:
            return f.read().strip()

    # Initiales Passwort = admin
    default_pw = b"admin"
    pw_hash = bcrypt.hashpw(default_pw, bcrypt.gensalt())
    with open(passwd_file, "wb") as f:
        f.write(pw_hash)
    print(f"🔑 Neues Admin-Standardpasswort 'admin' gesetzt → {passwd_file}")
    return pw_hash


def save_password_hash(app, new_password: str) -> bytes:
    """Speichert ein neues Passwort verschlüsselt in die Datei."""
    passwd_file = app.config["PASSWD_FILE"]
    pw_hash = bcrypt.hashpw(new_password.encode("utf-8"), bcrypt.gensalt())
    os.makedirs(os.path.dirname(passwd_file), exist_ok=True)
    with open(passwd_file, "wb") as f:
        f.write(pw_hash)
    return pw_hash

PASSWORD_HASH = load_password_hash(app)

class User(UserMixin):
    id = "admin"
    password_hash = PASSWORD_HASH

    @staticmethod
    def verify_password(candidate: str) -> bool:
        return bcrypt.checkpw(candidate.encode("utf-8"), User.password_hash)

    @staticmethod
    def change_password(new_password: str):
        User.password_hash = save_password_hash(app, new_password)

@login_manager.user_loader
def load_user(user_id):
    if user_id == "admin":
        return User()
    return None

def get_docs_list():
    """Liest alle Markdown-Dateien im docs-Ordner und gibt sie als dict zurück."""
    docs = []
    DOCS_DIR = Path(app.config["DOCS_DIR"])
    for f in sorted(DOCS_DIR.glob("*.md")):
        title = f.stem.replace("_", " ").capitalize()
        docs.append({
            "id": f.stem,
            "title": title,
            "filename": f.name
        })
    return docs

# ---------- Hilfsfunktionen für Varianten & Root-CA ---------------------------

def _variants_for_certfile(issued_dir: str, cert_filename: str):
    """
    Nimmt den Dateinamen einer .cert.pem und liefert vorhandene Varianten
    mit identischer Basename (ohne .cert.pem) zurück.
    """
    if not cert_filename or cert_filename == "N/A":
        return []

    base = cert_filename[:-9] if cert_filename.endswith(".cert.pem") else cert_filename
    exts = [".key.pem", ".csr.pem", ".cert.pem", ".fullchain.pem", ".p12"]
    variants = []
    for ext in exts:
        fname = f"{base}{ext}"
        fpath = os.path.join(issued_dir, fname)
        if os.path.exists(fpath):
            variants.append({"name": ext.lstrip("."), "filename": fname})
    return variants

# --- Routes ---
@app.route("/login", methods=["GET", "POST"])
def login():
    if request.method == "POST":
        if request.form["username"] == User.id and User.verify_password(request.form["password"]):
            login_user(User())
            return redirect(url_for("dashboard"))
        flash("Ungültige Anmeldedaten!", "danger")
    return render_template("login.html")

@app.route("/logout")
@login_required
def logout():
    logout_user()
    return redirect(url_for("login"))

@app.route("/")
@login_required
def dashboard():
    # Zertifikate wie gehabt einlesen
    #certs = list_certificates(app.config["CA_DIR"], app.config["ISSUED_DIR"])
    certs = list_certificates(app.config["CA_DIR"], app.config["ISSUED_DIR"], include_archive=True)
    #certs = list_certificates(app.config["CA_DIR"], app.config["ISSUED_DIR"], include_archive=False)

    # Für jedes Zertifikat die Varianten (key/csr/cert/fullchain/p12) ergänzen
    for c in certs:
        c["variants"] = _variants_for_certfile(app.config["ISSUED_DIR"], c.get("file"))

    # Root-CA nur als öffentliches Zertifikat bereitstellen
    root_cert_filename = "ca.cert.pem"  # liegt unter CA_DIR/certs/

    return render_template(
        "cert_list.html",
        certs=certs,
        root_cert=root_cert_filename  # im Template oben als Download anzeigen
    )

@app.route("/change_password", methods=["GET", "POST"])
@login_required
def change_password():
    if request.method == "POST":
        current_pw = request.form.get("current_password", "")
        new_pw = request.form.get("new_password", "")
        confirm_pw = request.form.get("confirm_password", "")

        if not User.verify_password(current_pw):
            flash("❌ Aktuelles Passwort ist falsch!", "danger")
            return redirect(url_for("change_password"))

        if new_pw != confirm_pw:
            flash("❌ Neue Passwörter stimmen nicht überein!", "danger")
            return redirect(url_for("change_password"))

        if len(new_pw) < 6:
            flash("⚠️ Neues Passwort muss mindestens 6 Zeichen haben!", "warning")
            return redirect(url_for("change_password"))

        User.change_password(new_pw)
        flash("✅ Passwort erfolgreich geändert!", "success")
        return redirect(url_for("dashboard"))

    return render_template("change_password.html")

@app.route("/download/<path:filename>")
@login_required
def download_file(filename):
    """
    Download für:
      - issued-Dateien (alles unter ISSUED_DIR)
      - Root-CA-Zertifikat (nur ca.cert.pem) unter CA_DIR/certs
    """
    # 1) Issued zuerst prüfen
    issued_path = os.path.join(app.config["ISSUED_DIR"], filename)
    if os.path.exists(issued_path):
        return send_from_directory(app.config["ISSUED_DIR"], filename, as_attachment=True)

    # 2) Root-CA: nur das öffentliche Zertifikat erlauben
    if filename == "ca.cert.pem":
        ca_certs_dir = os.path.join(app.config["CA_DIR"], "certs")
        ca_path = os.path.join(ca_certs_dir, filename)
        if os.path.exists(ca_path):
            return send_from_directory(ca_certs_dir, filename, as_attachment=True)
        abort(404, description="Root-CA Zertifikat nicht gefunden.")

    # 3) Alles andere blockieren
    abort(403, description=f"Zugriff auf {filename} nicht erlaubt oder Datei nicht gefunden.")

@app.route("/create", methods=["GET", "POST"])
@login_required
def create_cert():
    if request.method == "POST":
        cn = request.form.get("cn", "").strip()
        dns_list = [d.strip() for d in request.form.get("dns", "").split(",") if d.strip()]
        ip_list = [i.strip() for i in request.form.get("ips", "").split(",") if i.strip()]

        if not cn:
            flash("Common Name (CN) darf nicht leer sein!", "danger")
            return redirect(url_for("create_cert"))

        issue_script = app.config["ISSUE_SCRIPT"]

        if not os.path.isfile(issue_script):
            flash(f"Fehler: Ausgabeskript nicht gefunden ({issue_script})", "danger")
            return redirect(url_for("create_cert"))

        cmd = [issue_script, "-c", cn]
        for d in dns_list:
            cmd += ["-d", d]
        for i in ip_list:
            cmd += ["-i", i]

        import tempfile, subprocess
        with tempfile.NamedTemporaryFile(delete=False) as tmpout:
            result = subprocess.run(cmd, stdout=tmpout, stderr=subprocess.STDOUT, text=True)
            tmpout_path = tmpout.name

        if result.returncode == 0:
            flash(f"✅ Zertifikat für {cn} erfolgreich erstellt.", "success")
        else:
            flash(f"❌ Fehler bei der Zertifikatserstellung (siehe Log: {tmpout_path})", "danger")

        return redirect(url_for("dashboard"))

    return render_template("cert_create.html", title="Neues Zertifikat")

@app.route("/revoke/<serial>", methods=["POST"])
@login_required
def revoke_cert(serial):
    ca_dir = app.config["CA_DIR"]
    issued_dir = app.config["ISSUED_DIR"]
    archive_dir = app.config["ARCHIVE_DIR"]
    ca_pass = os.path.join(ca_dir, "private", "ca.pass")
    conf_file = os.path.join(ca_dir, "openssl.cnf")
    
    os.makedirs(archive_dir, exist_ok=True)


    cert_file = None
    base_name = None 

    # Alle Zertifikate durchsuchen und Seriennummer per openssl auslesen
    for f in os.listdir(issued_dir):
        if not f.endswith(".cert.pem"):
            continue
        full_path = os.path.join(issued_dir, f)

        try:
            result = subprocess.run(
                ["openssl", "x509", "-in", full_path, "-noout", "-serial"],
                capture_output=True, text=True, check=True
            )
            cert_serial = result.stdout.strip().split("=")[1].upper()

            # Seriennummern vergleichen (case-insensitive, ohne führende Nullen)
            if cert_serial.lstrip("0") == serial.lstrip("0"):
                cert_file = full_path
                base_name = f.rsplit(".cert.pem", 1)[0]  # <-- Basisname speichern
                break
        except Exception:
            continue

    if not cert_file:
        flash(f"❌ Kein Zertifikat mit Seriennummer {serial} gefunden!", "danger")
        return redirect(url_for("dashboard"))

    try:
        # Zertifikat widerrufen
        subprocess.run([
            "openssl", "ca",
            "-config", conf_file,
            "-revoke", cert_file,
            "-passin", f"file:{ca_pass}"
        ], check=True)

        # Neue CRL generieren
        crl_file = os.path.join(ca_dir, "crl", "ca.crl.pem")
        subprocess.run([
            "openssl", "ca",
            "-config", conf_file,
            "-gencrl",
            "-out", crl_file,
            "-passin", f"file:{ca_pass}"
        ], check=True)
        
        # Auch CRL als DER exportieren (für Windows / Firewalls)
        crl_der = os.path.join(ca_dir, "crl", "ca.crl")
        subprocess.run([
            "openssl", "crl",
            "-in", crl_file,
            "-outform", "DER",
            "-out", crl_der
        ], check=True)
        
        # 📦 Zertifikatsdateien ins Archiv verschieben
        extensions = [".cert.pem", ".key.pem", ".csr.pem", ".fullchain.pem", ".p12"]
        moved_files = []
        for ext in extensions:
            src = os.path.join(issued_dir, base_name + ext)
            if os.path.exists(src):
                dst = os.path.join(archive_dir, os.path.basename(src))
                os.rename(src, dst)
                moved_files.append(os.path.basename(dst))

        flash(f"🔒 Zertifikat {serial} wurde widerrufen, CRL aktualisiert und ins Archiv verschoben ({len(moved_files)} Dateien).", "warning")

    except subprocess.CalledProcessError as e:
        flash(f"❌ Fehler beim Widerruf: {e}", "danger")

    return redirect(url_for("dashboard"))

@app.route("/renew/<serial>", methods=["POST"])
@login_required
def renew_cert(serial):
    issued_dir = app.config["ISSUED_DIR"]
    issue_script = app.config["ISSUE_SCRIPT"]

    cert_file = None
    cn = None
    san_list = []

    # Zertifikat anhand Seriennummer finden
    for f in os.listdir(issued_dir):
        if not f.endswith(".cert.pem"):
            continue
        full_path = os.path.join(issued_dir, f)
        try:
            result = subprocess.run(
                ["openssl", "x509", "-in", full_path, "-noout", "-serial"],
                capture_output=True, text=True, check=True
            )
            cert_serial = result.stdout.strip().split("=")[1].upper()
            if cert_serial.lstrip("0") == serial.lstrip("0"):
                cert_file = full_path
                break
        except Exception:
            continue

    if not cert_file:
        flash(f"❌ Kein Zertifikat mit Seriennummer {serial} gefunden!", "danger")
        return redirect(url_for("dashboard"))

    # CN und SAN auslesen
    try:
        cn = subprocess.run(
            ["openssl", "x509", "-in", cert_file, "-noout", "-subject"],
            capture_output=True, text=True, check=True
        ).stdout.strip().split("CN=")[-1]

        san_output = subprocess.run(
            ["openssl", "x509", "-in", cert_file, "-noout", "-text"],
            capture_output=True, text=True, check=True
        ).stdout
        for line in san_output.splitlines():
            if "DNS:" in line or "IP Address:" in line:
                san_list.append(line.strip())
    except subprocess.CalledProcessError:
        flash(f"❌ Konnte CN/SAN für Zertifikat {serial} nicht auslesen.", "danger")
        return redirect(url_for("dashboard"))

    # Neue Zertifikatserstellung (Renew)
    cmd = [issue_script, "-c", cn]
    for san in san_list:
        if "DNS:" in san:
            dns_name = san.split("DNS:")[-1].split(",")[0]
            cmd += ["-d", dns_name]
        if "IP Address:" in san:
            ip_addr = san.split("IP Address:")[-1].split(",")[0]
            cmd += ["-i", ip_addr]

    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        flash(f"🔁 Zertifikat {cn} wurde erfolgreich erneuert.", "success")
    except subprocess.CalledProcessError as e:
        flash(f"❌ Fehler beim Erneuern des Zertifikats {cn}: {e.stderr}", "danger")

    return redirect(url_for("dashboard"))

@app.route("/download/index")
@login_required
def download_cert_index():
    """Ermöglicht den Download der aktuellen CA index.txt."""
    ca_dir = app.config["CA_DIR"]
    index_file = os.path.join(ca_dir, "index.txt")

    if not os.path.exists(index_file):
        flash("❌ Keine Zertifikatsliste gefunden!", "danger")
        return redirect(url_for("dashboard"))

    # Eine temporäre, menschenlesbare Version (optional) erzeugen
    readable_index = os.path.join(tempfile.gettempdir(), "cert_index_readable.txt")
    with open(index_file, "r") as src, open(readable_index, "w") as dst:
        dst.write("# Status | Ablauf | Seriennummer | Subject\n")
        dst.write("# ===========================================\n")
        for line in src:
            parts = line.strip().split("\t")
            if len(parts) >= 6:
                status, expire, revdate, serial, _, subject = parts[:6]
                dst.write(f"{status}\t{expire}\t{serial}\t{subject}\n")
            elif len(parts) >= 4:
                status, expire, serial, subject = parts[:4]
                dst.write(f"{status}\t{expire}\t{serial}\t{subject}\n")
            else:
                dst.write(line)

    return send_from_directory(
        os.path.dirname(readable_index),
        os.path.basename(readable_index),
        as_attachment=True,
        download_name="cert_index.txt"
    )

@app.route("/crl/<filename>")
def serve_crl(filename):
    """Öffentliche Bereitstellung der CRL-Datei."""
    ca_dir = app.config["CA_DIR"]
    crl_dir = os.path.join(ca_dir, "crl")
    file_path = os.path.join(crl_dir, filename)

    if not os.path.exists(file_path):
        abort(404, description="CRL-Datei nicht gefunden.")

    # MIME-Type für CRL (PEM oder DER)
    if filename.endswith(".pem"):
        mimetype = "application/x-pem-file"
    elif filename.endswith(".crl") or filename.endswith(".der"):
        mimetype = "application/pkix-crl"
    else:
        mimetype = "application/octet-stream"

    return send_from_directory(crl_dir, filename, mimetype=mimetype)

@app.route("/cert/details/<serial>")
@login_required
def cert_details(serial):
    issued_dir = app.config["ISSUED_DIR"]

    cert_file = None
    # Zertifikat anhand Seriennummer finden
    for f in os.listdir(issued_dir):
        if f.endswith(".cert.pem"):
            full_path = os.path.join(issued_dir, f)
            try:
                result = subprocess.run(
                    ["openssl", "x509", "-in", full_path, "-noout", "-serial"],
                    capture_output=True, text=True, check=True
                )
                cert_serial = result.stdout.strip().split("=")[1].upper()
                if cert_serial.lstrip("0") == serial.lstrip("0"):
                    cert_file = full_path
                    break
            except subprocess.CalledProcessError:
                continue

    if not cert_file:
        return "Zertifikat nicht gefunden", 404

    # Zertifikatsdetails abrufen
    try:
        result = subprocess.run(
            ["openssl", "x509", "-in", cert_file, "-text", "-noout"],
            capture_output=True, text=True, check=True
        )
        return f"<pre style='font-family: monospace; white-space: pre-wrap;'>{result.stdout}</pre>"
    except subprocess.CalledProcessError as e:
        return f"Fehler beim Lesen des Zertifikats: {e}", 500

@app.route("/docs/<doc_id>")
@login_required
def show_doc(doc_id):
    """Zeigt eine Markdown-Datei im Template an."""
    DOCS_DIR = Path(app.config["DOCS_DIR"])
    file_path = DOCS_DIR / f"{doc_id}.md"
    if not file_path.exists():
        abort(404)
    
    # ✔ Markdown2 mit Extras: fenced code blocks, Tabellen etc.
    md_extras = [
        "fenced-code-blocks",   # ```bash ... ```
        "tables",               # GitHub-Style Tabellen
        "code-friendly",        # weniger aggressives Emphasis-Verhalten
        "strike",               # ~~durchgestrichen~~
        "smarty-pants",         # “Smart Quotes”, optionale Typografie
        "cuddled-lists",        # Listen ohne Leerzeile
    ]  
    html = markdown2.markdown(file_path.read_text(encoding="utf-8"), extras=md_extras)
    title = file_path.stem.replace("_", " ").capitalize()
    return render_template("docs.html", title=title, content=Markup(html))

@app.route("/docs/download/<doc_id>")
@login_required
def download_doc(doc_id):
    """Ermöglicht das Herunterladen der originalen Markdown-Datei."""
    from pathlib import Path
    DOCS_DIR = Path(app.config["DOCS_DIR"])
    file_path = DOCS_DIR / f"{doc_id}.md"
    if not file_path.exists():
        abort(404)
    return send_from_directory(
        DOCS_DIR,
        f"{doc_id}.md",
        as_attachment=True,
        download_name=f"{doc_id}.md"
    )

@app.context_processor
def inject_config():
    """Macht bestimmte Config-Werte in allen Templates verfügbar."""
    return dict(ALERT_TIMEOUT_MS=app.config.get("ALERT_TIMEOUT_MS", 4000))

@app.context_processor
def inject_docs_menu():
    """Stellt die Doku-Liste global allen Templates zur Verfügung."""
    return {"docs_menu": get_docs_list()}

#print(f"📁 CA_BASE_DIR = {app.config['CA_BASE_DIR']}")

if __name__ == "__main__":
    host = app.config.get("FLASK_HOST", "127.0.0.1")
    port = app.config.get("FLASK_PORT", 5000)
    debug = app.config.get("FLASK_DEBUG", False)

    app.run(host=host, port=port, debug=debug)