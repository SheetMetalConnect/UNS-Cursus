# Lesplan Sessie 6 — AI Agent op de UNS
**12 mei 2026 · 14:00–16:30 CET**

> **Hoofdles:** AI-agent abonneert op de UNS (MQTT + Kafka via TimescaleDB historian) en chat met de fabriek via MCP.
> **Bijzaak:** BigQuery-upload als korte cloud-demo, niet hands-on.

---

## Pre-flight check (voor 14:00)

| # | Check | Hoe |
|---|------|-----|
| 1 | UNS stack draait | `docker ps` — `umh-core`, `timescaledb`, `hivemq`, `nodered`, `grafana` healthy |
| 2 | TimescaleDB heeft data | `docker exec timescaledb psql -U grafanareader -d umh -c "SELECT count(*) FROM tag;"` — moet > 100k zijn |
| 3 | HiveMQ heeft live verkeer | CSV-replay flow draait (sessie 3/5) of simulator actief — check via MQTT Explorer of `mqtt_list_topics` |
| 4 | Werkorders/sales orders in DB | Uit sessie 5 — `query_work_orders` en `query_sales_orders` geven rijen terug |
| 5 | Claude Desktop open | Hamertje-icoon zichtbaar, beide MCP-servers staan in de lijst |
| 6 | MCP-server pad in config absoluut | `claude_desktop_config.json` checken — geen `~`, geen relatieve paden |
| 7 | **Heartbeat zichtbaar op broker** | Vóór 14:00: `mosquitto_sub -h localhost -t 'umh/v1/smc/agents/+/_status' -v` — moet elke 10s een bericht tonen van beide MCP-servers (`uns-mqtt-luke`, `uns-timescaledb-luke`). Geen heartbeat = backend ligt eruit, demo-vraag 1 faalt. |
| 8 | Backup-vragen klaar | Print uit, naast laptop — voor als demo hapert (zie onder) |
| 9 | BigQuery Console open | Project `ve-systems-486013`, dataset `uns_cursus`, query klaargezet |
| 10 | Discord open | `#cursusgroep` voor live Q&A en setup-hulp |
| 11 | Tabs open | GitHub repo `sessie-6/`, Grafana solar dashboard, MQTT Explorer (gefocust op `umh/v1/smc/agents/#` om heartbeat live te tonen) |

---

## 14:00–14:10 — Welkom + terugblik (10 min)

**Wat zegt Luke:**
- Welkom, laatste sessie van cohort 2026
- Recap sessie 5: ERP/MES event-driven, dedup, history
- Vandaag: laat een AI-agent met je fabriek chatten — dat is de hoofdles
- BigQuery komt vandaag ook langs maar als korte cloud-demo aan het einde

**Scherm:** sessie-5 architectuur → sessie-6 architectuur (recap-tabel uit handboek)

---

## 14:10–14:35 — Theorie AI Agent + MCP (25 min)

### 14:10–14:20 — Het idee (10 min)
**Wat zegt Luke:**
- Use cases van de werkvloer: "wat gebeurt er nu in lijn 3?", "hoeveel orders zijn vandaag klaar?", "waarom staat machine X stil?"
- Werkplaats-analogie: zes sessies lang gereedschap aan de wand gehangen — vandaag zetten we er een collega bij die het zelf pakt
- Agent vervangt geen dashboard, hij vervangt het tikken tussen jou en het antwoord

**Scherm:** handboek hoofdstuk "Het idee — chat met je fabriek"

### 14:20–14:35 — MCP uitleg + agent-as-backend (15 min)
**Wat zegt Luke (eerst de misvatting rechtzetten):**
- "De agent zit niet in Claude Desktop — Claude Desktop is alleen de telefoon. De agent is een **backend-service**."
- Architectuurplaatje uit handboek: chat-frontend → MCP-protocol → Python backend → MQTT/DB
- **Vier requirements aan een UNS-agent**: subscribe op UNS, status publiceren (heartbeat), API praten (historian), publiceren (scoped naar eigen namespace)
- Werkplaats-analogie: chat = telefoon, backend = medewerker in de werkplaats die ook bij dichte telefoon zijn werk doet
- Korte tabel: chat-frontend (Claude Desktop, geen heartbeat) vs agent-backend (MCP server, heartbeat) vs FOSS later (LibreChat)
- MCP = open standaard van Anthropic. API = losse calls; MCP = AI ziet je hele toolset en chained zelf
- Twee backend-servers voor de UNS: `uns-mqtt` (subscribe/publish/list/heartbeat) en `uns-timescaledb` (historian queries/heartbeat)
- "Geen MCP, geen plek in mijn stack"

**Scherm:** handboek "De agent is geen chatvenster — het is een backend" → architectuur-diagram → MQTT Explorer met live heartbeats op `umh/v1/smc/agents/#` (laat zien dat de agents écht in de UNS staan) → tool-tabellen per server

---

## 14:35–15:05 — Demo: chatten met de UNS (30 min, KERN)

> **Backup**: als Claude Desktop hapert, switch naar MCP Inspector (`uv run mcp dev src/server.py` → http://localhost:6274). Tools werken daar identiek, alleen zonder LLM erbovenop.

### Demo-runbook (Luke draait deze in volgorde)

> **Opener (vraag 1+2)** raakt direct de vier requirements: heartbeat (status zichtbaar in UNS) en scoped publish. Dit is dé manier om "agent als backend" tastbaar te maken — niet door uitleg, maar door de heartbeat live in MQTT Explorer te tonen naast Claude Desktop.

| # | Vraag | Verwachte tool | Verwachte vorm | Req |
|---|-------|---------------|----------------|-----|
| 1 | "Wat is de status van mijn agent? Leeft hij nog?" | `mqtt_subscribe` op `umh/v1/smc/agents/uns-mqtt-luke/_status` | JSON met `state: online`, `last_seen`, uptime | 2 (status) |
| 2 | "Publiceer een testbericht op je eigen agent-namespace." | `mqtt_publish` naar `umh/v1/smc/agents/uns-mqtt-luke/_test` | Confirmatie + topic; toon bericht aankomen in MQTT Explorer | 4 (publish, scoped) |
| 3 | "Welke MQTT topics zijn nu actief?" | `mqtt_list_topics` | Lijst topics, oa. `umh.v1.smc.vienna.solar...` | 1 (subscribe) |
| 4 | "Wat zijn de laatste 5 berichten op `umh.v1.smc.vienna.solar._historian`?" | `mqtt_subscribe` | JSON payloads met timestamp + value | 1 |
| 5 | "Welke assets heb ik in mijn fabriek?" | `list_assets` | ISA-95 hierarchie tabel | 3 (API) |
| 6 | "Wat was de gemiddelde solar yield vandaag?" | `query_sensors` met aggregate | Numeriek getal in kWh | 3 |
| 7 | "Vergelijk solar output van vandaag met gisteren — wat valt op?" | meerdere tools chained | Korte analyse + cijfers | 1+3 |
| 8 | "Hoeveel werkorders staan open en welke hebben prio 1?" | `query_work_orders` | Tabel met WO-nummers | 3 |
| 9 | "Wat is er gebeurd met werkorder WO-001?" | `query_work_order_history` | Audit trail rijen | 3 |
| 10 | "Geef een totaalrapport van de fabriek nu." | chained — agent kiest zelf | Samenvatting in mensentaal | alle |
| 11 | "Publiceer een test werkorder voor 25 stuks beugels op de CNC." | `mqtt_publish` | Confirmatie + topic + payload | 4 |
| 12 | **Vrije vraag uit de zaal** | n.v.t. | n.v.t. — toon dat de agent improviseert | n.v.t. |

**Tijdens demo benadrukken:**
- Hamertje-icoon: laat zien welke tools zichtbaar zijn voor de agent
- Tool-uitvoer wordt zichtbaar in Claude Desktop — geen black box
- Agent kiest zelf welke tool, soms meerdere achter elkaar
- Bij verificatie: open MQTT Explorer naast Claude Desktop voor demo 9 (bericht zien aankomen)

**Scherm:** Claude Desktop full screen, MQTT Explorer in tweede venster
**Files:** `mcp-servers/README.md` als deelnemers naar setup vragen

---

## 15:05–15:20 — Pauze (15 min)

Discord-link delen voor setup-vragen. Wie wil eigen vraag stellen na de break? Laat hem in chat zetten.

---

## 15:20–16:05 — Hands-on installatie + chat (45 min)

### Stap-voor-stap (deelnemers volgen)
1. **uv installeren** (als nog niet aanwezig): `curl -LsSf https://astral.sh/uv/install.sh | sh`
2. **Repo updaten**: `cd UNS-Cursus && git pull`
3. **Beide servers installeren**:
   ```bash
   cd mcp-servers/uns-timescaledb && uv sync
   cd ../uns-mqtt && uv sync
   ```
4. **Claude Desktop config aanpassen** — paste config-block uit handboek, vervang `<JOUW-PAD>`
5. **Claude Desktop volledig herstarten** (Quit, niet alleen close)
6. **Hamertje-icoon checken** — beide servers in de lijst?
7. **Eerste vragen stellen** — start met: *"Welke assets heb ik?"* en *"Welke MQTT topics zijn er?"*
8. **Eigen vraag** — wat zou jij in jouw fabriek willen weten?

### Luke loopt mee in Discord
Veelvoorkomende valkuilen (uit handboek):
- Pad in config niet absoluut → fout
- TimescaleDB niet draaiend → connection refused
- MQTT broker host: `localhost` voor host, `metalfab-hivemq` binnen Docker
- Claude Desktop "close window" sluit niet — Quit via menu nodig
- Geen Anthropic API key → Claude Desktop werkt op subscription, niet op API key

**Vrije sessie**: zodra iemand werkt, mag die zelf experimenteren. Luke stelt eigen vragen voor wie blijft hangen.

---

## 16:05–16:15 — Bijzaak demo: BigQuery cloud (10 min)

**Wat zegt Luke:**
- Voor zware analyses op weken aan data: dezelfde UNS data ook richting cloud
- UNS blijft de bron, BigQuery is abonnee
- Architectuur: HiveMQ → UMH Core → Redpanda → Benthos flow → BigQuery (batched)
- Werkplaats-analogie: vrachtbrief, niet brief per schroef
- Kosten: < $1/maand voor normale fabrieksstroom

**Demo (3 dingen, snel):**
1. Open `flows/uns-to-bigquery.yaml` — toon bloblang mapping en batch policy (1 min)
2. BigQuery Console — toon dataset `uns_cursus` met geladen tabellen (1 min)
3. Run één voorbeeld query — `02-solar-forecast.sql` ARIMA forecast, toon grafiek (5 min)

**Niet hands-on.** Wie het zelf wil draaien: scripts en setup-instructies staan in `sessie-6/README.md`.

**Scherm:** flow YAML → BigQuery Console → query result
**Files:** `flows/uns-to-bigquery.yaml`, `bigquery/02-solar-forecast.sql`

---

## 16:15–16:30 — Afsluiting cursus (15 min)

**Wat zegt Luke:**
- Recap: tabel "Wat we hebben gebouwd in 6 sessies" uit handboek
- Hoe verder:
  - Cohort 2027 (vroege aanmelding korting) — laat me weten als je iemand mee wil nemen
  - 1-op-1 vervolg (halfdaagse architectuur-sessie) — voor wie het in eigen fabriek wil neerzetten
  - Community: GitHub blijft open, Discord blijft draaien
- Certificaat: alle 6 sessies gevolgd → PDF + LinkedIn-badge volgt deze week
- **Feedback formulier delen** (Tally link in Discord) — 5 minuten, eindcursus eval
- Bedankt + afsluiten

**Scherm:** handboek tabel "Wat we hebben gebouwd", daarna feedback link
**Files:** Tally feedback formulier (link in Discord)

---

## Risk callouts

| Risico | Mitigatie |
|--------|-----------|
| **Heartbeat-vraag (demo 1) hapert** | Backend ligt eruit of `AGENT_NAME` env var niet gezet. Fallback: skip naar demo 3 (`mqtt_list_topics`) en laat heartbeat zien direct in MQTT Explorer (toont nog steeds dat de backend leeft). Vermeld expliciet "de backend draait nog, alleen de tool-call faalt" — onderbouwt juist dat backend ≠ chat. |
| **Claude Desktop hamertje verdwijnt** | Quit volledig (cmd+Q), open opnieuw. Config-pad checken op absoluut pad. Backup: MCP Inspector via `uv run mcp dev src/server.py` op http://localhost:6274 |
| **HiveMQ heeft geen verkeer** | Start CSV-replay flow uit sessie 3 of MetalFab simulator. Demo-vragen 1, 2, 5 falen anders. |
| **TimescaleDB connection refused** | `docker compose up -d` in `stack/`. Wacht tot health = healthy. Check DSN in MCP env: `postgresql://grafanareader:changeme@localhost:5432/umh` |
| **Anthropic API rate limit tijdens demo** | Backup: stel minder vragen achter elkaar. Switch naar MCP Inspector — toont tool-output zonder LLM. |
| **Deelnemer heeft geen Claude Desktop subscription** | MCP Inspector werkt zonder LLM — kan tools nog steeds testen. Of meekijken in Discord. |
| **MQTT broker host fout binnen Docker** | Vanaf laptop = `localhost`. Vanaf binnen container = `metalfab-hivemq`. Voor MCP server (lokaal): `localhost`. |
| **BigQuery demo faalt** | Kort overslaan, niet stoppen — is bijzaak. Verwijs naar scripts in repo. |
| **Tijd loopt uit op hands-on** | Schrap demo 10 (totaalrapport) en demo 12 (vrije vraag uit zaal) in de hoofd-demo om 5 min te winnen. Demo 1+2 (heartbeat/publish) NOOIT skippen — die dragen de hoofdboodschap. |
| **Tijd loopt uit op afsluiting** | Skip BigQuery demo helemaal — die is bijzaak en staat in repo. |

---

## Backup-vragen voor de live demo

Als demo-vragen 1-10 niet lekker lopen (geen MQTT verkeer, lege tabel, etc.), gebruik deze fallback:

- *"Toon de schema van de UNS database"* → `uns://schema` resource
- *"Hoeveel rijen staan er totaal in de tag tabel?"* → `query_custom` met SELECT COUNT(*)
- *"Welke broker info heb ik?"* → `uns://broker-info` resource
- *"Publiceer een ping naar `umh.v1.test._raw` met payload {\"hello\":\"workshop\"}"* → `mqtt_publish`
- *"Subscribe op `umh.v1.test.#` voor 5 seconden en toon wat er binnenkomt"* → `mqtt_subscribe`
