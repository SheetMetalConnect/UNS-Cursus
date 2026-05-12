# Lesplan Sessie 6 — AI-integratie & Data naar de Cloud
**12 mei 2026 · 14:00–16:30 CET**

## Voor 14:00 — checklist

- [ ] `docker compose up -d` in `stack/` — UMH Core, TimescaleDB, Grafana, HiveMQ, Node-RED healthy
- [ ] Werkorders en sales orders in de DB (uit sessie 5)
- [ ] Claude Desktop geopend, MCP servers `uns-timescaledb` + `uns-mqtt` actief (hamertje-icoon zichtbaar)
- [ ] BigQuery Console open op project `ve-systems-486013`, dataset `uns_cursus`, tabellen + CSV's geladen
- [ ] GCP service account key op de server, `GOOGLE_APPLICATION_CREDENTIALS` gezet (test met `bq ls`)
- [ ] Tab open: Management Console → Data Flows
- [ ] Tab open: Grafana dashboards
- [ ] Tab open: GitHub repo `sessie-6/`
- [ ] Discord open op `#cursusgroep`

---

## 14:00–14:10 — Welkom + terugblik (10 min)

**Wat zegt Luke:**
- Welkom, laatste sessie van cohort 2026
- Recap sessie 5: ERP/MES event-driven, dedup, history
- Vandaag: AI-laag erbovenop + cloud-brug
- Twee richtingen: AI bevraagt fabriek (MCP) + fabriek vult cloud (BigQuery)

**Scherm:** sessie-5 architectuur diagram → sessie-6 architectuur diagram (recap-tabel uit handboek)
**Files:** geen

---

## 14:10–14:50 — Theorie + MCP demo (40 min)

### 14:10–14:25 — MCP uitleg + live demo (15 min)
**Wat zegt Luke:**
- MCP = open standaard van Anthropic
- API = losse calls; MCP = AI ziet je hele toolset en chained zelf
- "Geen MCP, geen plek in mijn stack"

**Demo:** Claude Desktop, vragen achter elkaar:
1. "Welke assets heb ik in mijn fabriek?"
2. "Toon de laatste 10 sensormetingen van de machining lijn"
3. "Hoeveel werkorders staan open en welke hebben prio 1?"
4. "Publiceer een test werkorder voor 25 stuks beugels op de CNC machine"

**Scherm:** Claude Desktop full screen, daarnaast MQTT Explorer voor verificatie van de publish
**Files:** `mcp-servers/README.md` voor setup-instructies (deelnemers volgen later)

### 14:25–14:50 — BigQuery + UNS-bridge theorie (25 min)
**Wat zegt Luke:**
- Waarom cloud: schaal, toegang, beheer
- UNS blijft de bron, cloud is abonnee
- Architectuur: Redpanda → Benthos → BigQuery (batched, $1/maand)
- Werkplaats-analogie: vrachtbrief, niet brief per schroef

**Scherm:** `flows/uns-to-bigquery.yaml` openzetten en bloblang doornemen, dan BigQuery Console met dataset `uns_cursus` en de drie tabellen
**Files:** `flows/uns-to-bigquery.yaml`, `bigquery/01-create-tables.sql`

---

## 14:50–15:10 — Live BigQuery demo (20 min)

### Demo 1 — Solar forecast (7 min)
**Wat zegt Luke:** "Hoeveel stroom morgen?" → ARIMA_PLUS detecteert dag/nacht patroon
**Scherm:** BigQuery Console → run `02-solar-forecast.sql` stap voor stap → laat forecast grafiek zien
**Files:** `bigquery/02-solar-forecast.sql`

### Demo 2 — Anomaly detection (7 min)
**Wat zegt Luke:** "Draait mijn machine normaal?" → zelfde model, andere vraag
**Scherm:** Run `03-anomaly-detection.sql` → toon `is_anomaly = TRUE` rijen
**Files:** `bigquery/03-anomaly-detection.sql`

### Demo 3 — Weer regressie (6 min)
**Wat zegt Luke:** "Welke weerfactor telt het meest?" → ML.WEIGHTS
**Scherm:** Run `04-weather-regression.sql` → toon weights tabel, daarna ML.PREDICT met fictieve weerwaarden
**Files:** `bigquery/04-weather-regression.sql`

---

## 15:10–15:25 — Pauze (15 min)

Discord-link delen voor vragen. Wie wil eigen demo doen na de break? Laat hem in chat zetten.

---

## 15:25–16:10 — Hands-on (45 min)

### Track A — MCP installeren (15 min)
Deelnemers volgen `mcp-servers/README.md`:
1. `uv` installeren
2. `git pull` op repo
3. `uv venv && uv pip install -e .` voor beide servers
4. Claude Desktop config aanpassen
5. Herstarten + eerste vraag stellen

**Luke loopt mee in Discord voor vragen.** Veelvoorkomende valkuilen:
- Pad in config niet absoluut → fout
- TimescaleDB niet draaiend → connection refused
- MQTT broker host: `localhost` voor host, `metalfab-hivemq` binnen Docker

### Track B — BigQuery ML zelf draaien (30 min)
1. GCP project aanmaken (gratis tier)
2. Dataset `uns_cursus` aanmaken
3. `01-create-tables.sql` draaien
4. CSV's uploaden via BigQuery Console (3 bestanden)
5. Demo queries kopieren en runnen
6. Optioneel: eigen variant maken (andere horizon, andere features)

**Optioneel als de tijd het toelaat:** stand-alone flow `uns-to-bigquery.yaml` deployen op eigen UMH-instance.

---

## 16:10–16:30 — Q&A + cohort 2027 / certificaten (20 min)

**Wat zegt Luke:**
- Korte recap: wat hebben we in 6 sessies gebouwd (tabel uit handboek)
- Hoe verder:
  - Cohort 2027 (vroege aanmelding korting)
  - 1-op-1 advies (halfdaagse architectuur-sessie)
  - Community: GitHub blijft open, Discord blijft draaien
  - Recap video's 4-6 volgen
- Certificaat: alle 6 sessies gevolgd → PDF + LinkedIn-badge
- **Feedback formulier delen** (Tally link in Discord) — eindcursus eval, 5 minuten
- Deelnemersdemo's als er tijd over is

**Scherm:** handboek tabel "Wat we hebben gebouwd in 6 sessies", daarna feedback link
**Files:** Tally feedback formulier (Luke maakt vooraf aan)

---

## Risk callouts

| Risico | Mitigatie |
|--------|-----------|
| **Simulator broker `95.217.14.139:1883` ligt eruit** | Gebruik lokale HiveMQ (`localhost:1883`). MetalFab simulator container draait lokaal in de stack — werk daarmee voor MCP demo. |
| **BigQuery vereist GCP project + auth** | Vooraf checken: `bq ls uns_cursus` moet werken. Service account key aanwezig en `GOOGLE_APPLICATION_CREDENTIALS` gezet. |
| **Claude Desktop MCP servers niet zichtbaar** | Hamertje-icoon onderin: zo niet, config-pad checken (absoluut pad), Claude Desktop herstarten. Backup: terminal demo met `uv run mcp dev src/server.py` op Inspector (`http://localhost:6274`). |
| **BigQuery quota/billing prompt** | Eerst checken dat billing alert + budget gezet zijn op GCP. Demo queries vallen ruim binnen gratis tier. |
| **Deelnemers zonder GCP account** | Track B optioneel — kijk mee met Luke's scherm. Nadruk op MCP-track die offline werkt. |
| **Tijd loopt uit** | Schrap deelnemersdemo's, hou cohort 2027 + certificaten + feedback link kort. |
