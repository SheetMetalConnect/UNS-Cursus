# Sessie 5 — ERP- & MES-integratie

## Bestanden

### Deel 1 — Sales Orders (API-ingest)

| Bestand | Deploy als | Wat het doet |
|---------|-----------|-------------|
| `sql/03-erp-sales-orders.sql` | DBeaver | `erp_sales_order` tabel |
| `flows/api-sales-order.yaml` | Standalone | HTTP API endpoint (:8090) → UNS |
| `flows/sales-order-bridge.yaml` | Standalone | UNS → `erp_sales_order` tabel |
| `nodered/flow_polling_sales_orders.json` | Node-RED import | NocoDB polling → UMH Core API |

### Deel 2 — Work Orders (event-driven bridge)

| Bestand | Deploy als | Wat het doet |
|---------|-----------|-------------|
| `sql/04-erp-work-orders.sql` | DBeaver | `erp_work_order` + history tabellen |
| `flows/mqtt-to-uns-bridge.yaml` | Standalone | MQTT → Redpanda |
| `flows/work-order-process.yaml` | Standalone | Deduplicatie (create/update/duplicate) |
| `flows/work-order-to-timescale.yaml` | Standalone | Opslag + history |
| `flows/uns-to-mqtt-bridge.yaml` | Standalone | Feedback → MQTT |
| `nodered/flow_work_order_testing.json` | Node-RED import | End-to-end test (4 knoppen) |
| `nodered/flow_work_order_publisher.json` | Node-RED import | NocoDB polling → MQTT |
| `nodered/flow_work_order_monitor.json` | Node-RED import | Monitor feedback |

### Demo data

| Bestand | Doel |
|---------|------|
| `demo/sales_orders_demo.csv` | 5 sales orders voor NocoDB |

## NocoDB

```bash
# Draait al in de stack (docker-compose.yaml)
# Poort: 8088
```

## Node-RED flows

Vervang in de polling flows:
- `TABLE_ID_HIER` → je NocoDB Table ID
- `XC_TOKEN_HIER` → je NocoDB API Token

## Topic paden

De flows gebruiken `umh/v1/smc/vienna/` als locatie. Pas dit aan naar je eigen ISA-95 hiërarchie:
- `smc` → je enterprise naam (uit Management Console)
- `vienna` → je site naam (uit Management Console)

De bridge flows (in `flows/`) gebruiken wildcards en werken met elke locatie.

## Vereisten

- Asset moet bestaan in de `asset` tabel met matchende `enterprise` + `site` kolommen
- De bridge flows moeten gedeployed zijn via de Management Console (Stand-alone → Add)
