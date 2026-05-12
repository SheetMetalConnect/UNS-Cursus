# UNS Cursus — Sessie 6 Handboek: AI-integratie & Data naar de Cloud

**12 mei 2026 · Van fabriek naar cloud, van data naar voorspelling**

---

## Terugblik

Sessie 5 hebben we ERP- en MES-data event-driven gemaakt. Sales orders via API, werkorders via MQTT met deduplicatie en historie. Nu ligt er een database vol met sensor-, machine-, en ordergegevens — en die archiefkast wil je niet alleen archiveren. Je wil er **vragen aan stellen**.

Vandaag bouwen we dat in twee richtingen:

1. **AI praat met je fabriek** — Claude Desktop bevraagt je UNS direct via MCP-servers
2. **Data naar de cloud** — UNS-stream naar BigQuery, voorspellingen met BigQuery ML

Geen Python notebooks. Geen data scientists. SQL en YAML — meer heb je niet nodig.

---

## Waarom data naar de cloud?

Op je lokale machine is TimescaleDB perfect voor real-time dashboards en directe analyses. Maar zodra je modellen wil trainen op weken aan data, of meerdere fabrieken wil vergelijken, loop je tegen drie dingen aan:

- **Schaal** — modellen trainen op miljoenen rijen kost rekenkracht die je niet altijd lokaal hebt
- **Toegang** — een leverancier of adviseur moet erbij kunnen zonder VPN-gedoe
- **Beheer** — backups, replicatie, disaster recovery: dat doet de cloud beter dan jij

De UNS blijft de bron. Cloud is een **abonnee**, geen vervanger. Je kiest welke topics je doorzet en wat je lokaal houdt.

> **Werkplaats-analogie:** je werkbank blijft in de werkplaats. De cloud is je archief in een externe opslag — je stuurt er kopieën naartoe van wat je later nog wil doorzoeken, maar het origineel staat nog op de vloer.

---

## Deel 1 — MCP: AI praat met je fabriek

### Wat is MCP?

**Model Context Protocol** is een open standaard van Anthropic. Het lost één probleem op: hoe geef je een AI-model toegang tot jouw systemen zonder elke keer data te copy-pasten?

Verschil met een gewone API:
- **API** = jij stuurt losse calls, de AI weet niets van je systeem
- **MCP** = de AI ziet welke tools beschikbaar zijn, kiest zelf de juiste, en chained ze aan elkaar

Voor de UNS hebben we twee MCP-servers gebouwd:

| Server | Wat het doet |
|--------|-------------|
| `uns-timescaledb` | Claude bevraagt de fabrieksdatabase (assets, sensoren, orders) |
| `uns-mqtt` | Claude leest en publiceert MQTT-berichten op de UNS |

### Live demo — Claude Desktop met je fabriek

Voorbeeldvragen die we live laten zien:

- *"Welke assets heb ik in mijn fabriek?"*
- *"Toon de laatste 10 sensormetingen van de machining lijn"*
- *"Hoeveel werkorders staan open en welke hebben prio 1?"*
- *"Wat is de gemiddelde cyclustijd van de afgelopen 24 uur?"*
- *"Publiceer een test werkorder voor 25 stuks beugels op de CNC machine"*

Claude doet dit niet door magie — hij roept de MCP-tools aan, leest de output, en formuleert een antwoord in mensentaal. Jij ziet welke tools hij gebruikt.

### Setup voor deelnemers

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
cd UNS-Cursus && git pull
cd mcp-servers/uns-timescaledb && uv venv && uv pip install -e .
cd ../uns-mqtt && uv venv && uv pip install -e .
```

Daarna Claude Desktop config aanpassen (zie `mcp-servers/README.md`) en herstarten.

---

## Deel 2 — Data naar BigQuery

### Architectuur

```
HiveMQ (MQTT) ──► UMH Core ──► Redpanda (UNS) ──► Benthos flow ──► BigQuery
                                                       │
                                                       └─► batched: 500 msg of 30s
```

Twee flows liggen klaar in de repo:

| Flow | Wat het doet |
|------|-------------|
| `flows/uns-to-bigquery.yaml` | UNS → BigQuery (gestructureerd, per topic naar juiste tabel) |
| `flows/mqtt-to-bigquery-raw.yaml` | MQTT → BigQuery (raw payloads, voor exploratie) |

### BigQuery setup

1. GCP project aanmaken (gratis tier — je krijgt $300 credit, BigQuery zelf is grotendeels gratis voor deze volumes)
2. BigQuery Console → dataset `uns_cursus` aanmaken
3. Service account aanmaken met BigQuery Data Editor rol → key downloaden
4. Service account key op de UMH server zetten, `GOOGLE_APPLICATION_CREDENTIALS` instellen
5. `bigquery/01-create-tables.sql` uitvoeren in de BigQuery Console
6. CSV's uploaden naar de tabellen (solar, weather, machine)
7. Flow deployen via Management Console → Data Flows → Stand-alone

### Kosten

Met batches van 500 berichten of elke 30 seconden zit je onder de $1/maand voor een normale fabrieksstroom. BigQuery rekent op opslag (paar cent per GB) en queries (eerste 1 TB/maand gratis).

> **Werkplaats-analogie:** je stuurt geen brief voor elke schroef die je gebruikt. Je verzamelt een vrachtbrief en stuurt die één keer per dag op. Batching werkt hetzelfde.

---

## Deel 3 — Drie AI use cases met BigQuery ML

Geen Python. Geen Jupyter. Alleen SQL.

### Use case 1 — Solar forecast (ARIMA_PLUS)

**Vraag:** *"Hoeveel stroom leveren mijn panelen morgen?"*

```sql
CREATE OR REPLACE MODEL uns_cursus.solar_forecast_model
OPTIONS(
  model_type = 'ARIMA_PLUS',
  time_series_timestamp_col = 'time',
  time_series_data_col = 'yield_kwh',
  auto_arima = TRUE
) AS
SELECT time, yield_kwh FROM uns_cursus.solar_training;

SELECT * FROM ML.FORECAST(MODEL uns_cursus.solar_forecast_model,
  STRUCT(1440 AS horizon, 0.9 AS confidence_level));
```

ARIMA_PLUS detecteert automatisch dag/nacht patronen. Je krijgt een voorspelling per minuut voor de komende 24 uur, mét confidence interval.

**Script:** `bigquery/02-solar-forecast.sql`

### Use case 2 — Anomaly detection op machine runtime

**Vraag:** *"Draait mijn machine normaal?"*

```sql
SELECT * FROM ML.DETECT_ANOMALIES(
  MODEL uns_cursus.machine_anomaly_model,
  STRUCT(0.95 AS anomaly_prob_threshold),
  (SELECT time, run_time FROM uns_cursus.machine_training))
WHERE is_anomaly = TRUE;
```

Hetzelfde ARIMA-model, maar dan om afwijkingen te vlaggen. Te lange runtime, te korte cyclus, onverwachte stilstand — allemaal uit één query.

**Script:** `bigquery/03-anomaly-detection.sql`

### Use case 3 — Weer → power regressie

**Vraag:** *"Welke weerfactor bepaalt mijn opbrengst?"*

```sql
CREATE OR REPLACE MODEL uns_cursus.weather_power_model
OPTIONS(model_type = 'LINEAR_REG', input_label_cols = ['yield_kwh']) AS
SELECT yield_kwh, solar_irradiance, temperature_c, humidity_pct,
       cloud_cover_pct, wind_speed_kmh
FROM uns_cursus.weather_solar_combined;

SELECT * FROM ML.WEIGHTS(MODEL uns_cursus.weather_power_model)
ORDER BY ABS(weight) DESC;
```

`ML.WEIGHTS` toont feature importance — welke variabele telt het meest? Spoiler: solar irradiance wint, maar bewolking en temperatuur tellen ook mee.

**Script:** `bigquery/04-weather-regression.sql`

---

## Wat we hebben gebouwd in 6 sessies

| Sessie | Resultaat |
|--------|-----------|
| 1 | UNS concept + UMH Core kennismaking |
| 2 | Docker stack: TimescaleDB, Grafana, Node-RED |
| 3 | MQTT, OPC UA, Modbus bridges naar machines |
| 4 | Grafana dashboards + NocoDB als mini-ERP |
| 5 | ERP-integratie: API, MQTT dedup, history, webhooks |
| 6 | AI: MCP, BigQuery ML, cloud streaming |

Je hebt nu een werkende UNS, lokale dashboards, ERP-integratie, en een brug naar de cloud voor AI-analyse. Dat is precies de stack die grote fabrieken voor zes cijfers laten bouwen — alleen draait die van jou op je eigen hardware en kun je hem zelf beheren.

---

## Hoe verder?

### Cohort 2027
We draaien deze workshop opnieuw begin 2027. Wil je collega's, partners, of klanten meenemen? Laat het me weten — vroege aanmeldingen krijgen voorrang en korting.

### 1-op-1 advies
Voor wie deze stack in zijn eigen fabriek wil neerzetten: ik kom langs voor een halfdaagse architectuur-sessie. We mappen jouw machines, ERP, en use cases op de UNS — concreet plan, geen verkooppraat.

### Community
- **GitHub repo** blijft open en wordt onderhouden
- **Discord** blijft draaien voor vragen tussen cohorts
- **Recap video's** sessie 4-6 volgen na deze sessie

### Certificaat
Iedereen die alle 6 sessies heeft gevolgd krijgt een certificaat van deelname (PDF + LinkedIn-badge).

---

## Voorbereiding voor vandaag

- UNS stack draait (`docker compose up -d` in `stack/`)
- Werkorders en sales orders in de database (uit sessie 5)
- Optioneel: GCP account aangemaakt (anders kijken we mee bij de demo)
- Optioneel: Claude Desktop geinstalleerd (anders kijken we mee bij de demo)

---

## Terminologie

| Term | Betekenis |
|------|-----------|
| MCP | Model Context Protocol — open standaard waarmee AI tools en data kan gebruiken |
| Claude Desktop | Desktop-app van Anthropic met MCP-ondersteuning |
| BigQuery | Google's serverless data warehouse — SQL op enorme datasets |
| BigQuery ML | ML-modellen trainen en gebruiken vanuit SQL queries |
| ARIMA_PLUS | Tijdreeksmodel dat automatisch seizoenspatronen detecteert |
| Anomaly detection | Afwijkingen vlaggen tov verwacht patroon |
| Linear regression | Voorspellen van een waarde op basis van meerdere variabelen |
| Feature importance | Welke input-variabele heeft de grootste invloed op de uitkomst |
| Service account | GCP-account voor systemen (geen mens) — gebruikt door de Benthos flow |
| Batching | Berichten verzamelen voor je ze stuurt — efficienter en goedkoper |
| Stand-alone flow | Benthos/Redpanda Connect flow die los van een protocol bridge draait |
