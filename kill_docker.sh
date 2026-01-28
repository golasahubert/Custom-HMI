#!/bin/bash

echo "[+] Force removing ALL Docker containers (running & stopped)..."

# Pobieramy ID wszystkich kontenerów (-a = all, -q = only IDs)
all_containers=$(sudo docker ps -aq)

if [ -n "$all_containers" ]; then
  # Używamy rm -f (force). To "zabija" działające i usuwa zatrzymane w jednym kroku.
  sudo docker rm -f $all_containers
  echo "[✓] All containers have been nuked."
else
  echo "[-] No containers found to remove."
fi

echo "[+] Removing all unused Docker networks..."
# Network prune -f jest bezpieczniejsze i skuteczniejsze niż ręczne filtrowanie custom
sudo docker network prune -f > /dev/null 2>&1

echo "[✓] Cleanup complete."
