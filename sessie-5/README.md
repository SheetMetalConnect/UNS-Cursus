# Sessie 5 — ERP- & MES-integratie (Data Bridges)

Vandaag bouwen we twee manieren om externe data in je UNS te krijgen:

1. **Deel 1 — Sales Orders (API-ingest):** NocoDB → Node-RED → POST naar UMH API → upsert in database
2. **Deel 2 — Work Orders (event-driven bridge):** NocoDB → Node-RED → MQTT → deduplicatie → database + history

## Leerdoelen

- Een REST API endpoint opzetten in je UNS (schrijf-endpoint)
- Het verschil begrijpen tussen API-ingest en event-driven bridges
- Deduplicatie implementeren (create/update/duplicate)
- Een history/audit trail opzetten voor orderwijzigingen
- Non-event-driven systemen event-driven maken via polling

---

## Deel 1 — Sales Orders (API-ingest)

```
NocoDB          Node-RED         UMH Core API        Redpanda         TimescaleDB
(ERP)           (poll)           (:8090)             (UNS)            (opslag)

sales_orders → GET API → POST /api/v1/ → _erp.sales_orders → erp_sales_order
                                                                (upsert)
```

### Stap 1.1 — SQL schema deployen

Open DBeaver, verbind met `localhost:5432/umh` (postgres / changeme).

Voer het script uit: [`sql/03-erp-sales-orders.sql`](sql/03-erp-sales-orders.sql)

Dit maakt de `erp_sales_order` tabel aan — een eenvoudige upsert-tabel zonder history.

### Stap 1.2 — API endpoint deployen

Open de Management Console en deploy deze 2 flows als **Stand-alone → Add**:

**1. API endpoint:**
- Bestand: [`flows/api-sales-order.yaml`](flows/api-sales-order.yaml)
- Naam: `api-sales-order`
- Dit opent een HTTP endpoint op poort 8090

**2. Bridge naar database:**
- Bestand: [`flows/sales-order-bridge.yaml`](flows/sales-order-bridge.yaml)
- Naam: `sales-order-bridge`
- Dit leest van de UNS en schrijft naar `erp_sales_order`

### Stap 1.3 — Test met curl

```bash
curl -X POST http://localhost:8090/api/v1/ \
  -H "Content-Type: application/json" \
  -d '{
    "order_id": "SO-TEST-001",
    "customer_name": "Testbedrijf BV",
    "status": "Open",
    "milestone": "Open",
    "due_date": "2026-05-15",
    "order_date": "2026-04-28"
  }'
```

Check DBeaver: `SELECT * FROM erp_sales_order;`

### Stap 1.4 — NocoDB koppelen

Importeer in Node-RED: [`nodered/flow_polling_sales_orders.json`](nodered/flow_polling_sales_orders.json)

**Vervang:**
- `TABLE_ID_HIER` → je NocoDB sales_orders Table ID
- `XC_TOKEN_HIER` → je NocoDB API Token

Klik **Poll (handmatig)** → check debug sidebar → check DBeaver.

Klaar! Je hebt nu een werkende API waar elk systeem naartoe kan POSTen.

---

## Deel 2 — Work Orders (event-driven bridge)

Nu bouwen we het complexere patroon: via MQTT en Redpanda, met deduplicatie en history tracking.

```
NocoDB          Node-RED         HiveMQ        UMH Core (Redpanda)          TimescaleDB
(ERP)           (poll)           (MQTT)        (data bridges)               (opslag)

werkorders → publish naar  → _work_order  → mqtt-to-uns-bridge
               MQTT          /process       → work-order-process
                                                (create/update/duplicate)
                                             → work-order-to-timescale
                                                (upsert + history)
                                             → uns-to-mqtt-bridge
                                                → terug naar MQTT
                                                  → monitor in Node-RED
```

### Waarom dit patroon?

In Deel 1 overschrijven we altijd alles. Dat betekent:
- Je weet niet of er iets **echt veranderd** is
- Je hebt geen **history** — wanneer ging de order van "Nieuw" naar "Klaar"?
- Elke poll schrijft naar de database, ook als er niks gewijzigd is

De event-driven bridge lost dit op met deduplicatie en een audit trail.

### Stap 2.1 — SQL schema deployen

Voer uit in DBeaver: [`sql/04-erp-work-orders.sql`](sql/04-erp-work-orders.sql)

Dit maakt drie dingen aan:

| Object | Doel |
|--------|------|
| `get_asset_id()` | Functie die ISA-95 locatie omzet naar een asset ID |
| `erp_work_order` | Huidige staat van elke werkorder (wordt overschreven bij update) |
| `erp_work_order_history` | Audit trail — elke wijziging wordt bewaard |

### Stap 2.2 — Data bridge flows deployen

Deploy deze 4 flows in de Management Console als **Stand-alone → Add**:

**Deploy in deze volgorde:**

| # | Bestand | Naam | Functie |
|---|---------|------|---------|
| 1 | [`flows/mqtt-to-uns-bridge.yaml`](flows/mqtt-to-uns-bridge.yaml) | `mqtt-to-uns-bridge` | MQTT → Redpanda |
| 2 | [`flows/work-order-process.yaml`](flows/work-order-process.yaml) | `work-order-process` | Deduplicatie |
| 3 | [`flows/work-order-to-timescale.yaml`](flows/work-order-to-timescale.yaml) | `work-order-to-timescale` | Opslag + history |
| 4 | [`flows/uns-to-mqtt-bridge.yaml`](flows/uns-to-mqtt-bridge.yaml) | `uns-to-mqtt-bridge` | Feedback naar MQTT |

Controleer in de Management Console dat alle 4 flows **active** zijn.

### Stap 2.3 — End-to-end test

Importeer in Node-RED: [`nodered/flow_work_order_testing.json`](nodered/flow_work_order_testing.json)

De flow heeft twee groepen:

**Blauw — Verstuur test data** (4 knoppen):

| Knop | Wat het stuurt | Verwacht resultaat |
|------|---------------|-------------------|
| 1. Nieuwe werkorder | WO-TEST-001, status Nieuw | CREATE |
| 2. Update status | WO-TEST-001, status Bezig | UPDATE |
| 3. Duplicate | WO-TEST-001, status Bezig (zelfde) | DUPLICATE |
| 4. Tweede werkorder | WO-TEST-002, ander product | CREATE |

**Groen — Monitor feedback** (3 listeners):
- `CREATE` — luistert op `_work_order/create`
- `UPDATE` — luistert op `_work_order/update`
- `DUPLICATE` — luistert op `_work_order/duplicate`

### Stap 2.4 — NocoDB koppelen

Importeer in Node-RED: [`nodered/flow_work_order_publisher.json`](nodered/flow_work_order_publisher.json)

**Vervang:**
- `TABLE_ID_HIER` → je NocoDB werkorders Table ID
- `XC_TOKEN_HIER` → je NocoDB API Token

### Stap 2.5 — Testen met NocoDB data

**Eerste poll (alles is nieuw):**
1. Klik **Poll (handmatig)** in de Publisher tab
2. Debug sidebar: 5x **CREATE**
3. Check DBeaver: `SELECT * FROM erp_work_order;` → 5 rijen
4. Check: `SELECT * FROM erp_work_order_history;` → 5 rijen

**Tweede poll (duplicaten):**
1. Klik nogmaals op **Poll** (zonder iets te veranderen)
2. Debug sidebar: 5x **DUPLICATE** → niks opgeslagen
3. Check: `SELECT count(*) FROM erp_work_order_history;` → nog steeds 5

**Derde poll (update):**
1. Wijzig in NocoDB de status van WO-001 van "Nieuw" naar "Bezig"
2. Klik op **Poll**
3. Debug sidebar: 1x **UPDATE** (WO-001) + 4x **DUPLICATE**
4. Check history: `SELECT * FROM erp_work_order_history WHERE order_nr = 'WO-001' ORDER BY recorded_at;`
   → 2 rijen: eerst CREATE, dan UPDATE

---

## History queries in Grafana

Open Grafana (localhost:3000) en maak een nieuw panel:

### Alle werkorders (huidige staat)
```sql
SELECT order_nr, product, customer, qty, status,
       priority, due_date, change_type, updated_at
FROM erp_work_order
ORDER BY order_nr;
```

### History van een specifieke werkorder
```sql
SELECT order_nr, status, change_type, recorded_at
FROM erp_work_order_history
WHERE order_nr = 'WO-001'
ORDER BY recorded_at;
```

### Alle sales orders (Deel 1)
```sql
SELECT order_id, customer_name, status, milestone,
       due_date, order_date, updated_at
FROM erp_sales_order
ORDER BY order_id;
```

---

## Hoe maak je een non-event-driven systeem event-driven?

De meeste ERP-systemen (Exact, SAP, Ridder) hebben geen MQTT output. Maar ze hebben wel een **database** of **API** die je kunt pollen.

**Deel 1 patroon (API-ingest):**
1. Node-RED pollt de ERP API op een interval
2. POST elk record naar de UMH Core API
3. De bridge schrijft het naar de database (upsert)
4. Simpel, maar geen deduplicatie of history

**Deel 2 patroon (event-driven bridge):**
1. Node-RED pollt de ERP database/API op een interval
2. Publish elk record naar MQTT: `umh/v1/{locatie}/_work_order/process`
3. De process-flow vergelijkt met de vorige versie in TimescaleDB
4. Alleen echte wijzigingen worden opgeslagen (create/update)
5. Duplicaten worden genegeerd — geen onnodige writes

---

## Veelvoorkomende problemen

| Probleem | Oorzaak | Oplossing |
|----------|---------|-----------|
| API geeft HTTP 000 | api-sales-order niet deployed | Deploy via Management Console |
| Geen data in monitor | mqtt-to-uns-bridge niet active | Check Management Console |
| Alles is "create" terwijl data al bestaat | Schema niet uitgevoerd | Check DBeaver: bestaat `erp_work_order`? |
| Error in process flow | `get_asset_id()` niet aangemaakt | Voer SQL schema opnieuw uit |
| Node-RED MQTT error | Broker niet bereikbaar | Check of HiveMQ draait: `docker ps` |

---

## Bestanden

```
sessie-5/
  README.md                              <- deze handleiding

  sql/
    03-erp-sales-orders.sql              <- Deel 1: sales order tabel (simpel)
    04-erp-work-orders.sql               <- Deel 2: work order + history tabellen

  flows/
    api-sales-order.yaml                 <- Deel 1: HTTP API endpoint
    sales-order-bridge.yaml              <- Deel 1: UNS → erp_sales_order
    mqtt-to-uns-bridge.yaml              <- Deel 2: MQTT → Redpanda
    uns-to-mqtt-bridge.yaml              <- Deel 2: Redpanda → MQTT (feedback)
    work-order-process.yaml              <- Deel 2: deduplicatie
    work-order-to-timescale.yaml         <- Deel 2: opslag + history

  nodered/
    flow_polling_sales_orders.json       <- Deel 1: poll NocoDB → API
    flow_work_order_testing.json         <- Deel 2: end-to-end test (4 knoppen)
    flow_work_order_publisher.json       <- Deel 2: poll NocoDB → MQTT
    flow_work_order_monitor.json         <- Deel 2: monitor feedback (standalone)

  demo/
    sales_orders_demo.csv                <- 5 demo sales orders voor NocoDB
```
