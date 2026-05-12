# UNS Cursus — Sessie 6 Handboek: AI Agent op de UNS

**12 mei 2026 · Chatten met je fabriek via MCP**

---

## Terugblik sessie 5

Vorige sessie hebben we ERP- en MES-data event-driven gemaakt. Sales orders via API, werkorders via MQTT met deduplicatie en historie. Je archiefkast is nu volgestopt met sensor-, machine- en ordergegevens. Vandaag halen we daar het laatste rendement uit: we laten een AI-agent rechtstreeks met je fabriek praten.

> **Werkplaats-analogie:** je hebt zes sessies lang netjes gereedschap aan de wand gehangen. Vandaag zetten we er een collega bij die het zelf kan pakken — jij hoeft alleen nog te zeggen wat je wil weten.

---

## Het idee — chat met je fabriek

Stel je voor dat je tegen een collega zegt:

- *"Wat gebeurt er nu in lijn 3?"*
- *"Hoeveel orders zijn vandaag afgerond?"*
- *"Waarom staat machine X stil?"*

Geen dashboard openzetten. Geen SQL tikken. Gewoon vragen. Dat is wat een AI-agent op de UNS doet: hij **abonneert zich op je MQTT- en Kafka-topics**, hij **bevraagt je historian**, en hij geeft antwoord in mensentaal.

### Use cases die er vandaag toe doen

| Vraag van de werkvloer | Wat de agent doet |
|------------------------|-------------------|
| "Wat zijn de laatste meetwaarden van de solar-installatie?" | Subscribe op MQTT topic, leest live berichten |
| "Hoeveel werkorders staan open?" | Query op TimescaleDB, telt rijen |
| "Vergelijk vandaag met gisteren" | Combineert live data + historische query |
| "Geef een statusrapport van de fabriek" | Chained tools — assets, orders, sensoren |

De agent vervangt geen dashboard. Hij vervangt **het tikken** dat tussen jou en een antwoord zit.

---

## De agent is geen chatvenster — het is een backend

Voordat we MCP induiken: een misvatting rechtzetten. Veel mensen denken "de agent zit in Claude Desktop". Klopt niet. **Claude Desktop is alleen de telefoon waarmee je belt.** De agent zelf — de collega die het werk doet — is een backend-service die persistent draait, abonneert op de UNS, een hartslag publiceert, en queries uitvoert.

```
   [Cursist/Luke]
        |
        v (chat)
   [Chat UI: Claude Desktop]   <-- alleen UI-laag, "de telefoon"
        |
        v (MCP-protocol)
   [Backend: Python MCP-servers]  <-- DIT IS DE AGENT, "de medewerker"
        |
        +--> MQTT subscribe + publish (HiveMQ)
        +--> TimescaleDB query (historian)
        +--> Status-heartbeat naar UNS
```

> **Werkplaats-analogie:** de chat-UI is de telefoon op je bureau. De backend MCP-server is de medewerker in de werkplaats die het gereedschap pakt, meet, rapporteert en bijhoudt of hij nog leeft. Als de telefoon uitstaat, doet de medewerker gewoon zijn werk verder.

### Vier eisen aan een UNS-agent

Wij definieren een agent op de UNS niet als "een chat-app", maar als een backend-service die deze vier dingen kan:

1. **Subscribe op de UNS** — abonneert op MQTT/Kafka-topics (lezen wat er gebeurt)
2. **Status publiceren** — publiceert elke 10s een heartbeat op `umh/v1/smc/agents/<naam>/_status` met state (`online` / `idle` / `processing` / `offline`). Daardoor zie je in de UNS zelf welke agents leven.
3. **Met API's praten** — query de TimescaleDB-historian, analyseer en visualiseer data
4. **Publiceren** — schrijf writes/commands naar de UNS, scoped naar de eigen agent-namespace voor veiligheid

Een chat-UI zonder heartbeat, zonder persistent subscribe, zonder publish-rechten is **geen agent** — dat is een gespreksvenster met tools. Het echte werk gebeurt in de backend.

### Chat-frontend vs agent-backend vs FOSS-alternatief

| Laag | Voorbeeld | Heartbeat? | Persistent? |
|------|-----------|-----------|-------------|
| Chat-frontend | Claude Desktop, Cursor | Nee | Nee — start/stop met app |
| Agent-backend | `uns-mqtt`, `uns-timescaledb` (Python MCP) | Ja | Ja — long-running service |
| FOSS-frontend (later) | LibreChat self-hosted | n.v.t. (zelfde backend) | n.v.t. |

LibreChat is een open-source alternatief voor de chat-UI dat je zelf kunt hosten — komt later beschikbaar als optie. De backend (onze MCP-servers) blijft hetzelfde.

---

## Hoe werkt het — Model Context Protocol

**Model Context Protocol (MCP)** is een open standaard van Anthropic. Het lost één probleem op: hoe geef je een AI-model toegang tot jouw systemen zonder data te copy-pasten?

Verschil met een gewone API:

- **API** = jij stuurt losse calls, de AI weet niets van je systeem
- **MCP** = de AI ziet welke tools beschikbaar zijn, kiest zelf de juiste, en chained ze aan elkaar

### Twee MCP-servers (de agent-backends) voor de UNS

| Server | Wat het doet | Op welke topic/tabel |
|--------|-------------|----------------------|
| `uns-mqtt` | Subscribe, publish, list topics, heartbeat | HiveMQ broker (`umh.v1.#` + `umh/v1/smc/agents/<naam>/_status`) |
| `uns-timescaledb` | Sensoren, werkorders, sales orders, custom SQL, heartbeat | TimescaleDB historian |

Beide servers publiceren elke 10s hun eigen status naar de UNS. Daardoor kun je in MQTT Explorer of via een query letterlijk zien welke agents leven — net als elke andere asset op je vloer.

### Architectuur (uitgewerkt)

```
Chat-frontend (Claude Desktop / Cursor / LibreChat)
    |
    |-- MCP (stdio) --> [BACKEND: uns-mqtt] -----------> HiveMQ (:1883) ---> Redpanda (Kafka)
    |                          |                              ^
    |                          +-- heartbeat 10s -------------+ (umh/v1/smc/agents/uns-mqtt/_status)
    |
    |-- MCP (stdio) --> [BACKEND: uns-timescaledb] ---> TimescaleDB (:5432)
                               |
                               +-- heartbeat 10s ------> HiveMQ (umh/v1/smc/agents/uns-timescaledb/_status)
```

De chat-frontend draait op je laptop. De MCP-servers (de echte agents) draaien als child process en blijven leven zolang de chat-app actief is. De UNS draait in Docker. Niets gaat naar de cloud — behalve de chat-prompts naar Anthropic, waar het LLM zelf zit.

> **Werkplaats-analogie:** MCP is de "iedereen verstaat dezelfde taal" afspraak. De chat praat MCP, de agent-backend praat MCP, dus ze begrijpen elkaar zonder dat jij voor elke koppeling iets moet bouwen.

---

## Live demo — chatten met de UNS

We laten dit live zien op Luke's stack. Volg mee in Discord.

### Demo-vragen die we draaien

Eerste twee vragen prikken direct de vier requirements aan: status (heartbeat), publiceren (eigen namespace), subscribe (UNS lezen), API (historian).

1. *"Wat is de status van mijn agent? Leeft hij nog?"* → agent queryt zijn eigen heartbeat-topic `umh/v1/smc/agents/uns-mqtt/_status` (**requirement 2: status publiceren is zichtbaar in UNS**)
2. *"Publiceer een testbericht op je eigen agent-namespace."* → `mqtt_publish` naar `umh/v1/smc/agents/<naam>/_test` (**requirement 4: publish, scoped**)
3. *"Welke MQTT topics zijn nu actief op mijn broker?"* → `mqtt_list_topics` (**requirement 1: subscribe/zien**)
4. *"Wat zijn de laatste 5 berichten op `umh.v1.smc.vienna.solar._historian`?"* → `mqtt_subscribe`
5. *"Welke assets heb ik in mijn fabriek?"* → `list_assets` (**requirement 3: API/historian**)
6. *"Wat was de gemiddelde solar yield vandaag?"* → `query_sensors`
7. *"Vergelijk solar output van vandaag met gisteren — wat valt op?"* → meerdere tools chained
8. *"Hoeveel werkorders staan open en welke hebben prioriteit 1?"* → `query_work_orders`
9. *"Wat is er gebeurd met werkorder WO-001?"* → `query_work_order_history`
10. *"Geef een totaalrapport van de fabriek nu."* → chained — agent kiest zelf welke tools
11. *"Publiceer een test werkorder voor 25 stuks beugels op de CNC."* → `mqtt_publish`
12. **Vrije vraag uit de zaal** — laat een deelnemer iets vragen wat hij in zijn eigen fabriek zou willen weten

Bij elke vraag zie je in Claude Desktop welke tools de agent aanroept en welke output hij terugkrijgt — geen black box.

---

## Hands-on — installeer en chat

### Stap 1 — Stack draait

```bash
cd stack && docker compose up -d
```

Check: TimescaleDB en HiveMQ healthy.

### Stap 2 — Repo updaten en MCP-servers installeren

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh   # als je uv nog niet hebt
cd UNS-Cursus && git pull

cd mcp-servers/uns-timescaledb && uv sync
cd ../uns-mqtt && uv sync
```

### Stap 3 — Claude Desktop config

`Settings > Developer > Edit Config` opent `claude_desktop_config.json`. Plak deze block, vervang `<JOUW-PAD>` door het pad naar je checkout:

```json
{
  "mcpServers": {
    "uns-timescaledb": {
      "command": "uv",
      "args": ["--directory", "<JOUW-PAD>/UNS-Cursus/mcp-servers/uns-timescaledb", "run", "src/server.py"],
      "env": {
        "UNS_DB_DSN": "postgresql://grafanareader:changeme@localhost:5432/umh",
        "AGENT_NAME": "uns-timescaledb-<jouwnaam>"
      }
    },
    "uns-mqtt": {
      "command": "uv",
      "args": ["--directory", "<JOUW-PAD>/UNS-Cursus/mcp-servers/uns-mqtt", "run", "src/server.py"],
      "env": {
        "UNS_MQTT_HOST": "localhost",
        "UNS_MQTT_PORT": "1883",
        "AGENT_NAME": "uns-mqtt-<jouwnaam>"
      }
    }
  }
}
```

`AGENT_NAME` is verplicht — de backend gebruikt die om zijn heartbeat te publiceren op `umh/v1/smc/agents/<naam>/_status` en om publish-rechten te scopen naar `umh/v1/smc/agents/<naam>/...`. Vul je voornaam in zodat we in de demo zien wie er online is.

Herstart Claude Desktop. Je ziet linksonder een hamertje-icoon — daarin staan de tools van beide servers. In MQTT Explorer zou je nu binnen 10 seconden je eigen agent moeten zien verschijnen onder `umh/v1/smc/agents/`.

### Stap 4 — Stel je eerste vraag

Begin simpel:

> *"Welke assets heb ik in mijn fabriek?"*

Zie je een lijst? Dan werkt de TimescaleDB-server. Daarna:

> *"Welke MQTT topics zijn er actief?"*

Zie je topics? Dan werkt de MQTT-server. Vanaf hier ben je los — vraag wat je wil.

### Veelvoorkomende valkuilen

| Probleem | Oplossing |
|----------|-----------|
| Hamertje-icoon ontbreekt | Pad in config moet absoluut zijn (geen `~`). Claude Desktop volledig afsluiten en opnieuw openen. |
| `connection refused` (DB) | TimescaleDB draait niet — check `docker ps`. |
| Geen MQTT topics | HiveMQ draait niet of geen verkeer. Start de simulator-flow uit sessie 3. |
| MQTT host fout binnen Docker | Vanaf je laptop = `localhost`. Vanaf binnen een container = `metalfab-hivemq`. |

---

## Bijzaak — UNS data naar de cloud (BigQuery)

Voor zwaardere analyses op weken aan data wil je niet je lokale TimescaleDB belasten. Je laat dan dezelfde UNS-stream óók in de cloud landen — als abonnee.

### Architectuur

```
HiveMQ (MQTT) ──► UMH Core ──► Redpanda (UNS) ──► Benthos flow ──► BigQuery
                                                       │
                                                       └─► batched: 500 msg of 30s
```

### Wat er klaarligt in de repo

| Bestand | Wat het doet |
|---------|-------------|
| `flows/uns-to-bigquery.yaml` | Stand-alone Benthos dataflow: UNS → BigQuery |
| `bigquery/01-create-tables.sql` | BigQuery tabellen aanmaken |
| `bigquery/02-solar-forecast.sql` | ARIMA_PLUS forecast op solar yield |
| `bigquery/03-anomaly-detection.sql` | Anomaly detection op machine runtime |
| `bigquery/04-weather-regression.sql` | Linear regression weer → opbrengst |

### In een notendop

- UNS blijft de bron, cloud is een **abonnee**
- Batches van 500 berichten of elke 30 seconden — onder $1/maand voor een normale fabrieksstroom
- BigQuery ML traint modellen met SQL — geen Python, geen Jupyter

We laten dit vandaag alleen tonen. Wie het zelf wil draaien: scripts staan in de repo, instructies in `sessie-6/README.md` onderaan.

---

## Wat we hebben gebouwd in 6 sessies

| Sessie | Resultaat |
|--------|-----------|
| 1 | UNS concept + UMH Core kennismaking |
| 2 | Docker stack: TimescaleDB, Grafana, Node-RED |
| 3 | MQTT, OPC UA, Modbus bridges naar machines |
| 4 | Grafana dashboards + NocoDB als mini-ERP |
| 5 | ERP-integratie: API, MQTT dedup, history, webhooks |
| 6 | AI-agent op de UNS via MCP + cloud-brug naar BigQuery |

Je hebt nu een werkende UNS, lokale dashboards, ERP-integratie, een AI-agent die je fabriek bevraagt, en een brug naar de cloud voor zware analyse. Dat is precies de stack die grote fabrieken voor zes cijfers laten bouwen — alleen draait die van jou op je eigen hardware en kun je hem zelf beheren.

---

## Hoe verder?

### Cohort 2027
We draaien de workshop opnieuw begin 2027. Vroege aanmeldingen krijgen voorrang en korting.

### 1-op-1 vervolg
Voor wie deze stack in de eigen fabriek wil neerzetten: een halfdaagse architectuur-sessie. We mappen jouw machines, ERP en use cases op de UNS — concreet plan, geen verkooppraat.

### Community
- GitHub repo blijft open en wordt onderhouden
- Discord blijft draaien voor vragen tussen cohorts

### Certificaat
Iedereen die alle 6 sessies heeft gevolgd krijgt een certificaat van deelname (PDF + LinkedIn-badge).

### Feedback
Tally-formulier (link in Discord) — 5 minuten, eindcursus eval.

---

## Voorbereiding voor vandaag

- UNS stack draait (`docker compose up -d` in `stack/`)
- Werkorders en sales orders in de DB (uit sessie 5)
- HiveMQ heeft verkeer (CSV-replay flow draait of simulator actief)
- Optioneel: Claude Desktop alvast geinstalleerd (anders kijken we mee bij de demo)
- Optioneel: GCP account voor de BigQuery-tonen

---

## Terminologie

| Term | Betekenis |
|------|-----------|
| MCP | Model Context Protocol — open standaard waarmee AI tools en data kan gebruiken |
| MCP Server | Klein programma dat tools blootstelt aan een AI-client (hier: TimescaleDB en MQTT) |
| MCP Client | App waarin je chat (Claude Desktop, Cursor, eigen LLM-app) |
| Stdio transport | MCP-server start als child process van de client, communicatie via stdin/stdout |
| Tool calling | LLM die zelf kiest welke tool aan te roepen op basis van de vraag |
| Subscribe | Luisteren naar MQTT/Kafka topic — krijgt elk nieuw bericht |
| Historian | Database met historische tijdreeksdata (TimescaleDB) |
| BigQuery | Google's serverless data warehouse — SQL op enorme datasets |
| BigQuery ML | ML-modellen trainen en gebruiken vanuit SQL queries |
| Stand-alone flow | Benthos/Redpanda Connect flow die los van een protocol bridge draait |
