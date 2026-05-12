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
| 7 | Backup-vragen klaar | Print uit, naast laptop — voor als demo hapert (zie onder) |
| 8 | BigQuery Console open | Project `ve-systems-486013`, dataset `uns_cursus`, query klaargezet |
| 9 | Discord open | `#cursusgroep` voor live Q&A en setup-hulp |
| 10 | Tabs open | GitHub repo `sessie-6/`, Grafana solar dashboard, MQTT Explorer |

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

### 14:20–14:35 — MCP uitleg (15 min)
**Wat zegt Luke:**
- MCP = open standaard van Anthropic
- API = losse calls; MCP = AI ziet je hele toolset en chained zelf
- Twee servers voor de UNS: `uns-mqtt` (subscribe/publish/list) en `uns-timescaledb` (historian queries)
- Architectuur tonen: alles lokaal, alleen chat-prompts gaan naar Anthropic
- "Geen MCP, geen plek in mijn stack"

**Scherm:** architectuur-diagram, dan `mcp-servers/README.md`, dan de tool-tabellen per server

---

## 14:35–15:05 — Demo: chatten met de UNS (30 min, KERN)

> **Backup**: als Claude Desktop hapert, switch naar MCP Inspector (`uv run mcp dev src/server.py` → http://localhost:6274). Tools werken daar identiek, alleen zonder LLM erbovenop.

### Demo-runbook (Luke draait deze in volgorde)

| # | Vraag | Verwachte tool | Verwachte vorm |
|---|-------|---------------|----------------|
| 1 | "Welke MQTT topics zijn nu actief?" | `mqtt_list_topics` | Lijst topics, oa. `umh.v1.smc.vienna.solar...` |
| 2 | "Wat zijn de laatste 5 berichten op `umh.v1.smc.vienna.solar._historian`?" | `mqtt_subscribe` | JSON payloads met timestamp + value |
| 3 | "Welke assets heb ik in mijn fabriek?" | `list_assets` | ISA-95 hierarchie tabel |
| 4 | "Wat was de gemiddelde solar yield vandaag?" | `query_sensors` met aggregate | Numeriek getal in kWh |
| 5 | "Vergelijk solar output van vandaag met gisteren — wat valt op?" | meerdere tools chained | Korte analyse + cijfers |
| 6 | "Hoeveel werkorders staan open en welke hebben prio 1?" | `query_work_orders` | Tabel met WO-nummers |
| 7 | "Wat is er gebeurd met werkorder WO-001?" | `query_work_order_history` | Audit trail rijen |
| 8 | "Geef een totaalrapport van de fabriek nu." | chained — agent kiest zelf | Samenvatting in mensentaal |
| 9 | "Publiceer een test werkorder voor 25 stuks beugels op de CNC." | `mqtt_publish` | Confirmatie + topic + payload |
| 10 | **Vrije vraag uit de zaal** | n.v.t. | n.v.t. — toon dat de agent improviseert |

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
| **Claude Desktop hamertje verdwijnt** | Quit volledig (cmd+Q), open opnieuw. Config-pad checken op absoluut pad. Backup: MCP Inspector via `uv run mcp dev src/server.py` op http://localhost:6274 |
| **HiveMQ heeft geen verkeer** | Start CSV-replay flow uit sessie 3 of MetalFab simulator. Demo-vragen 1, 2, 5 falen anders. |
| **TimescaleDB connection refused** | `docker compose up -d` in `stack/`. Wacht tot health = healthy. Check DSN in MCP env: `postgresql://grafanareader:changeme@localhost:5432/umh` |
| **Anthropic API rate limit tijdens demo** | Backup: stel minder vragen achter elkaar. Switch naar MCP Inspector — toont tool-output zonder LLM. |
| **Deelnemer heeft geen Claude Desktop subscription** | MCP Inspector werkt zonder LLM — kan tools nog steeds testen. Of meekijken in Discord. |
| **MQTT broker host fout binnen Docker** | Vanaf laptop = `localhost`. Vanaf binnen container = `metalfab-hivemq`. Voor MCP server (lokaal): `localhost`. |
| **BigQuery demo faalt** | Kort overslaan, niet stoppen — is bijzaak. Verwijs naar scripts in repo. |
| **Tijd loopt uit op hands-on** | Schrap demo 8 (totaalrapport) en demo 10 (vrije vraag uit zaal) in de hoofd-demo om 5 min te winnen. |
| **Tijd loopt uit op afsluiting** | Skip BigQuery demo helemaal — die is bijzaak en staat in repo. |

---

## Backup-vragen voor de live demo

Als demo-vragen 1-10 niet lekker lopen (geen MQTT verkeer, lege tabel, etc.), gebruik deze fallback:

- *"Toon de schema van de UNS database"* → `uns://schema` resource
- *"Hoeveel rijen staan er totaal in de tag tabel?"* → `query_custom` met SELECT COUNT(*)
- *"Welke broker info heb ik?"* → `uns://broker-info` resource
- *"Publiceer een ping naar `umh.v1.test._raw` met payload {\"hello\":\"workshop\"}"* → `mqtt_publish`
- *"Subscribe op `umh.v1.test.#` voor 5 seconden en toon wat er binnenkomt"* → `mqtt_subscribe`
