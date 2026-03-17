# Grafana — Sessie 2 Handleiding

## Inloggen

- URL: http://localhost:3000
- User: admin
- Password: changeme

## Datasource verbinden (handmatig)

1. Ga naar **Connections → Data sources → Add data source**
2. Kies **PostgreSQL**
3. Vul in:
   - Host URL: `timescaledb:5432`
   - Database name: `umh`
   - Username: `grafanareader`
   - Password: `changeme`
   - TLS/SSL Mode: `disable`
4. Scroll naar **PostgreSQL details** → zet **TimescaleDB** aan
5. Klik **Save & Test** → "Database Connection OK"

## Query opbouwen — van simpel naar complex

### Niveau 1: Simpelste query (1 getal)

Gebruik: **Stat panel** — toont 1 waarde.

```sql
SELECT count(*) FROM asset;
```

Dit telt het aantal assets. Geen tijd, geen JOIN, geen filter.

### Niveau 2: Laatste waarde van 1 sensor

Gebruik: **Stat panel** — toont live waarde.

```sql
SELECT value
FROM tag t
JOIN asset a ON a.id = t.asset_id
WHERE a.asset_name = 'smc.workshop.tasmota.desk'
  AND t.tag_name = 'power'
ORDER BY t.time DESC
LIMIT 1;
```

Wat is nieuw: JOIN met asset tabel, filter op asset + tag, ORDER BY time DESC.

### Niveau 3: Tijdreeks (grafiek)

Gebruik: **Time series panel** — lijn of bar grafiek.

```sql
SELECT
  time_bucket('30 seconds', t.time) AS time,
  avg(t.value) AS "Power (W)"
FROM tag t
JOIN asset a ON a.id = t.asset_id
WHERE a.asset_name = 'smc.workshop.tasmota.desk'
  AND t.tag_name = 'power'
  AND $__timeFilter(t.time)
GROUP BY 1
ORDER BY 1;
```

Wat is nieuw:
- `time_bucket('30 seconds', ...)` — TimescaleDB functie, groepeert data per interval
- `$__timeFilter(t.time)` — Grafana macro, filtert automatisch op de geselecteerde tijdrange
- `avg(t.value)` — gemiddelde per bucket
- Format moet op **Time series** staan

### Niveau 4: Meerdere lijnen (per device)

Gebruik: **Time series panel** — meerdere lijnen in 1 grafiek.

```sql
SELECT
  time_bucket('1 minute', t.time) AS time,
  a.line AS metric,
  avg(t.value) AS "Power (W)"
FROM tag t
JOIN asset a ON a.id = t.asset_id
WHERE a.enterprise = 'smc'
  AND t.tag_name = 'power'
  AND $__timeFilter(t.time)
GROUP BY 1, 2
ORDER BY 1;
```

Wat is nieuw:
- `a.line AS metric` — Grafana gebruikt de "metric" kolom als label voor elke lijn
- `GROUP BY 1, 2` — groepeert op tijd EN device
- Filter op enterprise i.p.v. specifiek asset → pakt alle Tasmota devices

### Niveau 5: Tekst data (tag_string)

Gebruik: **Table panel** — toont state changes.

```sql
SELECT
  t.time AS "Tijd",
  a.asset_name AS "Machine",
  t.tag_name AS "Tag",
  t.value AS "Status"
FROM tag_string t
JOIN asset a ON a.id = t.asset_id
WHERE $__timeFilter(t.time)
ORDER BY t.time DESC
LIMIT 50;
```

Wat is nieuw:
- Query op `tag_string` tabel i.p.v. `tag`
- Tekst waarden: "EXECUTE", "IDLE", "HELD", etc.
- Format moet op **Table** staan

### Niveau 6: OEE metrics (percentage gauge)

Gebruik: **Gauge panel** — toont percentage.

```sql
SELECT
  a.line AS metric,
  t.tag_name,
  avg(t.value) * 100 AS value
FROM tag t
JOIN asset a ON a.id = t.asset_id
WHERE a.enterprise = 'metalfab'
  AND t.tag_name LIKE 'oee.%'
  AND $__timeFilter(t.time)
GROUP BY 1, 2
ORDER BY 1, 2;
```

### Niveau 7: Schrijfsnelheid (inserts per minuut)

Gebruik: **Time series panel** (bar chart) — toont throughput.

```sql
SELECT
  time_bucket('1 minute', t.time) AS time,
  count(*) AS "inserts/min"
FROM tag t
WHERE $__timeFilter(t.time)
GROUP BY 1
ORDER BY 1;
```

### Niveau 8: Grafana variabelen

Maak een dashboard variable aan:
1. Dashboard settings → Variables → New variable
2. Type: Query
3. Query: `SELECT DISTINCT asset_name FROM asset ORDER BY asset_name`
4. Name: `asset`

Gebruik in een panel:
```sql
SELECT
  time_bucket('30 seconds', t.time) AS time,
  t.tag_name AS metric,
  avg(t.value) AS value
FROM tag t
JOIN asset a ON a.id = t.asset_id
WHERE a.asset_name = '$asset'
  AND $__timeFilter(t.time)
GROUP BY 1, 2
ORDER BY 1;
```

Nu kun je via een dropdown in het dashboard wisselen tussen assets.

## Belangrijke Grafana concepten

| Concept | Uitleg |
|---------|--------|
| `$__timeFilter(t.time)` | Grafana vervangt dit met de tijdrange die je selecteert (bijv. "Last 30 minutes") |
| `time_bucket('30s', time)` | TimescaleDB functie — groepeert data per tijdsinterval |
| `AS metric` | Kolom genaamd "metric" wordt automatisch het label van een lijn |
| Format: Time series | Voor grafieken — Grafana verwacht kolommen: time, metric (optioneel), value |
| Format: Table | Voor tabellen — elke kolom wordt een tabelkolom |
| `rawSql` | Gebruik altijd "Code" mode, niet de query builder |
