# Stack — Installatie & Gebruik

## Snel starten

```bash
cd stack
cp .env.example .env
# Vul je AUTH_TOKEN in (gratis via https://management.umh.app/)
nano .env
docker compose up -d
```

## Services

| Service | URL | Login |
|---------|-----|-------|
| UMH Management Console | https://management.umh.app | Jouw account |
| Grafana | http://localhost:3000 | admin / changeme |
| Node-RED | http://localhost:1880 | (geen login) |
| Portainer | http://localhost:9000 | (setup bij eerste keer) |
| TimescaleDB | localhost:5432 | postgres / changeme |
| HiveMQ MQTT | localhost:1883 | (geen auth) |

## Wat zit erin?

- **UMH Core** — Unified Namespace hub met Management Console
- **TimescaleDB** — PostgreSQL + tijdreeks extensie (hypertables)
- **Grafana** — Dashboards (3 voorbeelden provisioned)
- **HiveMQ** — Lokale MQTT broker
- **Node-RED** — Visuele flow programming
- **Portainer** — Container management UI

## Database schema

Het init script (`configs/timescaledb-init/01-init-schema.sql`) maakt automatisch aan:
- `asset` tabel — ISA-95 equipment hierarchy
- `tag` hypertable — numerieke tijdreeksdata
- `tag_string` hypertable — tekst tijdreeksdata
- `get_asset_id()` functie — auto-creatie van assets
- `kafkatopostgresqlv2` user — voor UMH Core schrijfrechten
- `grafanareader` user — voor Grafana leesrechten

## Stoppen & opschonen

```bash
# Stoppen (data blijft bewaard)
docker compose down

# Alles wissen (fresh start)
docker compose down -v
```

## Troubleshooting

```bash
# Status
docker ps

# Logs van een service
docker compose logs umh -f
docker compose logs timescaledb -f

# Database checken
docker exec timescaledb psql -U postgres -d umh -c "SELECT * FROM asset;"
docker exec timescaledb psql -U postgres -d umh -c "SELECT count(*) FROM tag;"
```
