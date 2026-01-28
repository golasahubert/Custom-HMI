#!/bin/bash

set -e  # Zatrzymuje skrypt przy każdym błędzie
cd "$(dirname "$0")"

# --- KONFIGURACJA KOLORÓW ---
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[+] $1${NC}"
}

err() {
    echo -e "${RED}[✘] $1${NC}"
}

# --- KROK 1: CZYSZCZENIE I INSTALACJA ZALEŻNOŚCI ---

log "Ensuring that previous environment is stopped..."
if [ -f "kill_docker.sh" ]; then
    sudo bash kill_docker.sh
else
    sudo docker-compose down -v --remove-orphans > /dev/null 2>&1 || true
fi

log "Updating APT and installing required system packages..."
sudo apt update
# Dodajemy netcat-openbsd do healthchecka
sudo apt install -y python3-venv docker.io docker-compose netcat-openbsd

log "Ensuring (again) that previous environment is stopped..."
if [ -f "kill_docker.sh" ]; then
    sudo bash kill_docker.sh
fi

# --- KROK 2: BUDOWANIE I START ---

log "Building and Starting containers..."
sudo docker-compose up -d --build

# --- KROK 3: HEALTHCHECK ---

TARGET_HOST="localhost"
TARGET_PORT="8080" # Port ScadaLTS
log "Waiting for services to initialize on port $TARGET_PORT..."

for i in {1..60}; do
    if nc -z $TARGET_HOST $TARGET_PORT; then
        log "Service is UP!"
        break
    fi
    echo -n "."
    sleep 2
done

if ! nc -z $TARGET_HOST $TARGET_PORT; then
    err "Warning: Service port is not reachable yet. Proceeding anyway, but scripts might fail."
fi

# --- KROK 4: PYTHON I PLAYWRIGHT ---

log "Setting up Python virtual environment..."
cd automation

if [ ! -d "venv" ]; then
    log "Creating virtual environment..."
    python3 -m venv venv || { err "Failed to create virtual environment."; exit 1; }
fi

# Definicja ścieżek do venv
VENV_PYTHON="$(pwd)/venv/bin/python"
VENV_PIP="$(pwd)/venv/bin/pip"
VENV_PLAYWRIGHT="$(pwd)/venv/bin/playwright"

if [ -f "requirements.txt" ]; then
    log "Installing Python dependencies..."
    $VENV_PIP install --upgrade pip
    $VENV_PIP install -r requirements
