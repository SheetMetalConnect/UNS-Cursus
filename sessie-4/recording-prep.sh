#!/usr/bin/env bash
# ==============================================================================
# recording-prep.sh — Verse UNS Cursus omgeving voor sessie-4 opname
# ==============================================================================
#
# Dit script:
#   1. Stopt en verwijdert alle UNS-gerelateerde containers
#   2. Verwijdert volumes die vers moeten zijn (TimescaleDB, Node-RED, Grafana, NocoDB)
#   3. Start de stack opnieuw op
#   4. Wacht tot alles healthy is
#   5. Print URLs om te testen
#
# Voorwaarde: archivering is klaar (stack/archive-2026-04-24/)
# RAAKT NIET AAN: Supabase, eryxon-demar, dashboard
#
# Gebruik:
#   chmod +x sessie-4/recording-prep.sh
#   ./sessie-4/recording-prep.sh
# ==============================================================================

set -euo pipefail

# Kleuren voor output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

STACK_DIR="$(cd "$(dirname "$0")/../stack" && pwd)"
QF2UNS_DIR="$HOME/Documents/GitHub/QF2UNS"

echo ""
echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  UNS Cursus — Verse omgeving voor opname  ${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# ------------------------------------------------------------------------------
# Stap 1: Controleer of archief bestaat
# ------------------------------------------------------------------------------
echo -e "${YELLOW}[1/7] Controleer archief...${NC}"
if [ ! -f "$STACK_DIR/archive-2026-04-24/timescaledb-dump.sql" ]; then
    echo -e "${RED}FOUT: Archief niet gevonden op $STACK_DIR/archive-2026-04-24/${NC}"
    echo "       Draai eerst de archivering voordat je deze prep uitvoert."
    exit 1
fi
echo -e "${GREEN}      Archief gevonden. Doorgaan.${NC}"
echo ""

# ------------------------------------------------------------------------------
# Stap 2: Stop en verwijder UNS containers (compose down)
# ------------------------------------------------------------------------------
echo -e "${YELLOW}[2/7] Stop en verwijder UNS containers...${NC}"

cd "$STACK_DIR"

# uns-cursus project (grafana, portainer, nodered, timescaledb, hivemq, nocodb)
echo "       Compose down: uns-cursus project..."
docker compose -p uns-cursus down 2>&1 | sed 's/^/       /'

# stack project (umh-core)
echo "       Compose down: stack project (umh-core)..."
docker compose -p stack down 2>&1 | sed 's/^/       /'

# qf2uns project
if [ -f "$QF2UNS_DIR/docker-compose.snijnoord.yaml" ]; then
    echo "       Compose down: qf2uns project..."
    cd "$QF2UNS_DIR"
    docker compose -f docker-compose.snijnoord.yaml -p qf2uns down 2>&1 | sed 's/^/       /'
    cd "$STACK_DIR"
fi

echo -e "${GREEN}      Alle UNS containers verwijderd.${NC}"
echo ""

# ------------------------------------------------------------------------------
# Stap 3: Verwijder volumes die vers moeten zijn
# ------------------------------------------------------------------------------
echo -e "${YELLOW}[3/7] Verwijder volumes voor verse start...${NC}"

# Volumes die vers moeten zijn voor de opname
VOLUMES_TO_REMOVE=(
    "uns-cursus_timescaledb-data"
    "uns-cursus_nodered-data"
    "uns-cursus_grafana-data"
    "uns-cursus_hivemq-data"
    "uns-cursus_portainer-data"
    "uns-cursus_umh-core-data"
    "stack_timescaledb-data"
    "stack_nodered-data"
    "stack_grafana-data"
    "stack_hivemq-data"
    "stack_portainer-data"
    "stack_umh-core-data"
    "nocodb-data"
)

for vol in "${VOLUMES_TO_REMOVE[@]}"; do
    if docker volume inspect "$vol" > /dev/null 2>&1; then
        docker volume rm "$vol" > /dev/null 2>&1 && \
            echo -e "       ${GREEN}Verwijderd: $vol${NC}" || \
            echo -e "       ${RED}Kon niet verwijderen: $vol (in gebruik?)${NC}"
    else
        echo "       Overgeslagen (bestaat niet): $vol"
    fi
done

echo ""

# ------------------------------------------------------------------------------
# Stap 4: Start de stack
# ------------------------------------------------------------------------------
echo -e "${YELLOW}[4/7] Start de stack...${NC}"
cd "$STACK_DIR"
docker compose up -d 2>&1 | sed 's/^/       /'
echo -e "${GREEN}      Stack gestart.${NC}"
echo ""

# ------------------------------------------------------------------------------
# Stap 5: Wacht tot alles healthy is
# ------------------------------------------------------------------------------
echo -e "${YELLOW}[5/7] Wacht tot services healthy zijn...${NC}"

SERVICES=("timescaledb" "grafana" "hivemq" "nodered")
MAX_WAIT=120
INTERVAL=5

for svc in "${SERVICES[@]}"; do
    elapsed=0
    printf "       %-15s " "$svc"
    while [ $elapsed -lt $MAX_WAIT ]; do
        status=$(docker inspect --format='{{.State.Health.Status}}' "$svc" 2>/dev/null || echo "missing")
        if [ "$status" = "healthy" ]; then
            echo -e "${GREEN}healthy${NC}"
            break
        fi
        sleep $INTERVAL
        elapsed=$((elapsed + INTERVAL))
        printf "."
    done
    if [ $elapsed -ge $MAX_WAIT ]; then
        echo -e "${RED}TIMEOUT na ${MAX_WAIT}s (status: $status)${NC}"
    fi
done

# umh-core heeft geen healthcheck, controleer of hij draait
printf "       %-15s " "umh-core"
if docker ps --format "{{.Names}}" | grep -q "^umh-core$"; then
    echo -e "${GREEN}running${NC}"
else
    echo -e "${RED}NOT RUNNING${NC}"
fi

# nocodb — check apart
printf "       %-15s " "nocodb"
nocodb_running=$(docker ps --format "{{.Names}}" | grep -c "^nocodb$" || true)
if [ "$nocodb_running" -gt 0 ]; then
    echo -e "${GREEN}running${NC}"
else
    echo -e "${YELLOW}not started (start handmatig als je NocoDB nodig hebt)${NC}"
fi

# portainer — geen healthcheck
printf "       %-15s " "portainer"
if docker ps --format "{{.Names}}" | grep -q "^portainer$"; then
    echo -e "${GREEN}running${NC}"
else
    echo -e "${RED}NOT RUNNING${NC}"
fi

echo ""

# ------------------------------------------------------------------------------
# Stap 6: Verifieer database init
# ------------------------------------------------------------------------------
echo -e "${YELLOW}[6/7] Controleer database initialisatie...${NC}"

# Wacht even zodat init scripts klaar zijn
sleep 3

tables=$(docker exec timescaledb psql -U postgres -d umh -t -c "SELECT count(*) FROM pg_tables WHERE schemaname = 'public';" 2>/dev/null | tr -d ' ')
assets=$(docker exec timescaledb psql -U postgres -d umh -t -c "SELECT count(*) FROM asset;" 2>/dev/null | tr -d ' ')
orders_exists=$(docker exec timescaledb psql -U postgres -d umh -t -c "SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'production_orders');" 2>/dev/null | tr -d ' ')

echo "       Tabellen in public schema: $tables"
echo "       Assets geladen: $assets"
echo "       production_orders tabel: $orders_exists"

if [ "$orders_exists" = "f" ]; then
    echo -e "       ${YELLOW}production_orders tabel bestaat nog niet (wordt in de opname aangemaakt via DBeaver)${NC}"
fi

echo ""

# ------------------------------------------------------------------------------
# Stap 7: Print URLs
# ------------------------------------------------------------------------------
echo -e "${YELLOW}[7/7] URLs voor de opname:${NC}"
echo ""
echo -e "  ${BLUE}Grafana${NC}             http://localhost:3000        (admin / changeme)"
echo -e "  ${BLUE}Node-RED${NC}            http://localhost:1880"
echo -e "  ${BLUE}NocoDB${NC}              http://localhost:8088        (vers account aanmaken)"
echo -e "  ${BLUE}HiveMQ${NC}              mqtt://localhost:1883"
echo -e "  ${BLUE}HiveMQ Web${NC}          http://localhost:8083"
echo -e "  ${BLUE}Portainer${NC}           http://localhost:9000"
echo -e "  ${BLUE}UMH Core API${NC}        http://localhost:8090"
echo -e "  ${BLUE}UMH Management${NC}      https://management.umh.app"
echo -e "  ${BLUE}TimescaleDB${NC}         localhost:5432 (postgres / changeme)"
echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  Klaar! Omgeving is vers voor de opname.  ${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo "Tip: NocoDB start met een vers account. Maak als eerste een account aan"
echo "     en importeer sessie-4/demo/workorders_demo.csv wanneer je daar bent"
echo "     in het draaiboek."
echo ""
