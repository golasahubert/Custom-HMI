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
# Usunąłem netcat, bo wracamy do sleep
sudo apt update
sudo apt install -y python3-venv docker.io docker-compose

log "Ensuring (again) that previous environment is stopped..."
if [ -f "kill_docker.sh" ]; then
    sudo bash kill_docker.sh
fi

# --- KROK 2: BUDOWANIE I START ---

log "Building and Starting containers..."
sudo docker-compose up -d --build

log "Waiting for containers to initialize..."
# POWRÓT DO LOGIKI SKRYPTU 2: Prosty sleep zamiast pętli.
# Zwiększyłem do 10s dla bezpieczeństwa (bazy danych), ale to tylko pauza.
sleep 10

# --- KROK 3: PYTHON I PLAYWRIGHT ---

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
    $VENV_PIP install -r requirements.txt
fi

# --- SEKCJA PLAYWRIGHT ---
# Sprawdzamy czy playwright się zainstalował w venv
if [ -f "$VENV_PLAYWRIGHT" ]; then
    log "Installing Playwright browsers and dependencies..."
    
    # 1. Instalacja binarek przeglądarek
    $VENV_PLAYWRIGHT install
    
    # 2. Instalacja zależności systemowych (sudo)
    sudo $VENV_PLAYWRIGHT install-deps
else
    log "Playwright executable not found in venv. Skipping browser setup."
fi

log "Running setup_import.sh..."
sudo bash setup_import.sh

cd ..

log "Build and setup complete."

# --- KROK 4: RESTART KOŃCOWY ---

log "Restarting the environment..."

if [ -f "stop_system.sh" ] && [ -f "start_system.sh" ]; then
    sudo bash stop_system.sh
    sudo bash start_system.sh
else
    log "External scripts not found, using docker-compose restart..."
    sudo docker-compose restart
fi

log "System Ready. Restart Complete."
