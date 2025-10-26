import os
from dotenv import load_dotenv

# Lädt Variablen aus config.env
load_dotenv(os.path.join(os.path.dirname(__file__), "config.env"))

class Config:
    SECRET_KEY = os.environ.get("SECRET_KEY", "devsecret")
    
    # Basis-CA-Verzeichnisse
    BASE_DIR = os.path.expanduser(os.getenv("BASE_DIR", "~/my-root-ca/"))
    CA_DIR = os.path.join(BASE_DIR, "ca")
    ISSUED_DIR = os.path.join(BASE_DIR, "issued")
    ARCHIVE_DIR = os.path.join(ISSUED_DIR, "archive")
    PASSWD_FILE = os.path.join(BASE_DIR, "config", "passwd.db")
    DOCS_DIR = os.path.join(BASE_DIR, "doku")

    # Pfade zu den Bash-Skripten (konfigurierbar)
    CA_SCRIPTS_DIR = os.path.join(BASE_DIR, "ca_tools_bash")
    ISSUE_SCRIPT = os.path.join(CA_SCRIPTS_DIR, "issue_server_cert.sh")
    #REVOKE_SCRIPT = os.path.join(CA_SCRIPTS_DIR, "revoke_cert.sh")
    #RENEW_SCRIPT = os.path.join(CA_SCRIPTS_DIR, "renew_cert.sh")
    
    # Root-Zertifikat (für Client-Import)
    CA_CERT_FILE = os.path.join(BASE_DIR, "certs", "ca.cert.pem")
    
    # Zeit in Millisekunden, wie lange Flash-Alerts sichtbar bleiben sollen
    ALERT_TIMEOUT_MS = 5000  # z. B. 10 Sekunden
    
    # Flask-Server-Einstellungen
    FLASK_HOST = "0.0.0.0"
    FLASK_PORT = 5001
    FLASK_DEBUG = True