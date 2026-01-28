#!/bin/bash

set -e  # Zatrzymuje skrypt przy każdym błędzie
cd "$(dirname "$0")"

# Kolory dla lepszej czytelności logów
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[+] $1${NC}"
}

err() {
    echo -e "${RED}[✘] $1${NC}"
}

log "Forcing a full cleanup of the previous Docker environment..."
# Używamy || true, aby skrypt nie przerwał się, jeśli nie ma co usuwać
sudo docker compose down -v --remove-orphans > /dev/null 2>&1 || true
sudo docker network prune -f > /dev/null 2>&1 || true

log "Building all Docker images..."
sudo docker compose build --no-cache

log "Starting all containers..."
sudo docker compose up -d

# --- SEKCJA HEALTHCHECK ---
# ScadaLTS i OpenPLC potrzebują czasu. Zamiast sleep, czekamy na port (np. 8080 dla ScadaLTS lub 502 dla OpenPLC)
# Wymaga zainstalowanego netcat (nc). Jeśli nie masz, dodaj: sudo apt install netcat-openbsd
TARGET_HOST="localhost"
TARGET_PORT="8080" # Zmień na port, na którym nasłuchuje Twoja główna usługa (np. ScadaLTS)

log "Waiting for services to initialize on port $TARGET_PORT..."
for i in {1..60}; do
    if nc -z $TARGET_HOST $TARGET_PORT; then
        log "Service is UP!"
        break
    fi
    echo -n "."
    sleep 2
done

# Jeśli po pętli usługa nadal nie działa, może warto przerwać?
if ! nc -z $TARGET_HOST $TARGET_PORT; then
    err "Service did not start in time. Check logs."
    # exit 1  # Odkomentuj, jeśli chcesz przerywać w tym momencie
fi
# --------------------------

log "Setting up Python virtual environment..."
cd automation

if [ ! -d "venv" ]; then
    log "Creating virtual environment..."
    python3 -m venv venv || { err "Failed to create virtual environment."; exit 1; }
fi

# Zamiast aktywować venv i używać sudo (co gubi ścieżki),
# używamy bezpośredniej ścieżki do pip i python wewnątrz venv.
# To gwarantuje użycie właściwych bibliotek.

VENV_PYTHON="$(pwd)/venv/bin/python"
VENV_PIP="$(pwd)/venv/bin/pip"

if [ -f "requirements.txt" ]; then
    log "Installing Python dependencies..."
    $VENV_PIP install --upgrade pip
    $VENV_PIP install -r requirements.txt
fi

log "Running setup_import.sh..."
# WAŻNE: Jeśli setup_import.sh wywołuje skrypty pythonowe,
# upewnij się, że w środku tego skryptu wywołujesz je przez "$VENV_PYTHON script.py",
# lub przekaż ścieżkę do interpretera.
# Jeśli setup_import.sh musi być sudo, użyj sudo z zachowaniem środowiska (trudne)
# LUB wywołaj pythona bezpośrednio z uprawnieniami (jeśli to kod pythonowy robi robotę):
# sudo $VENV_PYTHON skrypt_konfiguracyjny.py

# Zakładam, że setup_import.sh to wrapper. Uruchamiamy go:
sudo bash setup_import.sh

cd ..

log "Build and setup complete."

# Opcjonalny restart - jeśli ScadaLTS wymaga przeładowania configów
log "Restarting the environment..."
sudo docker compose restart

log "System Ready."
