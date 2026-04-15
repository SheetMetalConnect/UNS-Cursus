# Sessie 4 — Grafana Dashboards & ERP-integratie

## Vereisten

- Stack draaiend (sessie 2)
- Historian + bridges deployed (sessie 3)

## Bestanden

| Bestand | Deploy als | Wat het doet |
|---------|-----------|-------------|
| `flows/flow-api-workorder.yaml` | Standalone | HTTP POST endpoint (:8090) → UNS |
| `flows/flow-erp-order-bridge.yaml` | Standalone | UNS → `production_orders` tabel |
| `flows/flow-nocodb-webhook-ingest.yaml` | Standalone | NocoDB webhook (:8092) → UNS |
| `nodered/flow_polling_nocodb_v2_local.json` | Node-RED import | NocoDB polling → UMH Core API |
| `nodered/flow_event_out_dashboard.json` | Node-RED import | Formulier → POST NocoDB |
| `grafana/queries.sql` | Grafana panels | SQL queries voor dashboards |
| `demo/workorders_demo.csv` | NocoDB import | 10 demo werkorders |

## SQL tabel

Draai `../stack/configs/timescaledb-init/02-production-orders.sql` in DBeaver.

## NocoDB

```bash
docker run -d --name nocodb --network umh-network \
  -p 8088:8080 -v nocodb-data:/usr/app/data \
  -e NC_ALLOW_LOCAL_HOOKS=true \
  --restart unless-stopped nocodb/nocodb:latest
```
