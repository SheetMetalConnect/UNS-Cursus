# Sessie 6 — AI Agent op de UNS

> **Hoofdles:** AI-agent (backend-service) abonneert op de UNS, publiceert een heartbeat, query't de historian — bediend via een chat-frontend zoals Claude Desktop. MCP koppelt de twee.
> **Bijzaak:** BigQuery-upload als korte cloud-demo aan het eind van de sessie.

## De agent is geen chatvenster — het is een backend

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
        +--> Status-heartbeat naar UNS (umh/v1/smc/agents/<naam>/_status, elke 10s)
```

### Vier eisen aan een UNS-agent

1. **Subscribe op de UNS** — abonneert op MQTT/Kafka-topics
2. **Status publiceren** — heartbeat elke 10s op `umh/v1/smc/agents/<naam>/_status`, zichtbaar in de UNS zelf
3. **Met API's praten** — TimescaleDB-historian queryen, analyseren, visualiseren
4. **Publiceren** — schrijf writes/commands naar de UNS, scoped naar de eigen agent-namespace

Een chat-UI zonder heartbeat en zonder persistent subscribe is **geen agent** — dat is een gespreksvenster met tools. De backend is waar het werk gebeurt.

## Hoofdles — MCP Servers (chat-frontend praat met agent-backend)

Twee MCP-servers (de backends) laten een AI-agent rechtstreeks met je UNS chatten:

| Server | Wat het doet |
|--------|-------------|
| `mcp-servers/uns-mqtt` | Subscribe, publish, list topics op de HiveMQ broker + heartbeat |
| `mcp-servers/uns-timescaledb` | Sensoren, werkorders, sales orders, custom SQL op de historian + heartbeat |

Chat-frontend opties: Claude Desktop (gebruikt in deze sessie), Cursor, of later self-hosted via LibreChat.

Setup: zie [`mcp-servers/README.md`](../mcp-servers/README.md).

### Claude Desktop config

Open Claude Desktop → Settings → Developer → Edit Config en plak:

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

Vervang `<JOUW-PAD>` door het absolute pad naar je checkout en `<jouwnaam>` door je voornaam. `AGENT_NAME` is verplicht — de backend gebruikt het voor zijn heartbeat-topic en om publish-rechten te scopen naar `umh/v1/smc/agents/<naam>/...`. Herstart Claude Desktop volledig (Quit, niet alleen close).

Check of je agent leeft:
```bash
mosquitto_sub -h localhost -t 'umh/v1/smc/agents/+/_status' -v
```
Je moet binnen 10s je eigen agent voorbij zien komen.

### Voorbeeldvragen voor Claude Desktop

Eerste twee raken de vier requirements direct:

- "Wat is de status van mijn agent? Leeft hij nog?" (req 2: heartbeat)
- "Publiceer een testbericht op je eigen agent-namespace" (req 4: scoped publish)
- "Welke MQTT topics zijn nu actief?" (req 1: subscribe)
- "Wat zijn de laatste 5 berichten op `umh.v1.smc.vienna.solar._historian`?"
- "Welke assets heb ik in mijn fabriek?" (req 3: API)
- "Wat was de gemiddelde solar yield vandaag?"
- "Vergelijk solar output van vandaag met gisteren"
- "Hoeveel werkorders staan er open en welke hebben prioriteit 1?"
- "Geef een totaalrapport van de fabriek nu"
- "Publiceer een test werkorder naar MQTT"

### Veelvoorkomende valkuilen

| Probleem | Oplossing |
|----------|-----------|
| Hamertje-icoon ontbreekt | Pad in config moet absoluut zijn (geen `~`). Claude Desktop volledig afsluiten en opnieuw openen. |
| Connection refused (DB) | TimescaleDB draait niet — check `docker ps`. |
| Geen MQTT topics | HiveMQ draait niet of geen verkeer. Start de simulator-flow uit sessie 3. |
| MQTT host fout binnen Docker | Vanaf je laptop = `localhost`. Vanaf binnen een container = `metalfab-hivemq`. |

---

## Bijzaak — UNS data naar de cloud (BigQuery)

Voor zwaardere analyses op weken aan data: dezelfde UNS-stream óók in de cloud laten landen als abonnee. Niet hands-on tijdens de sessie, alleen demo. Wie het zelf wil draaien — alle scripts staan klaar.

### UNS → BigQuery Bridge

Live streaming van UNS data naar BigQuery via Benthos/Redpanda Connect.

| Bestand | Wat het doet |
|---------|-------------|
| `flows/uns-to-bigquery.yaml` | Stand-alone dataflow: UNS → BigQuery |

#### Setup

1. Service account key op de UMH server plaatsen
2. `GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json` instellen
3. Flow deployen via Management Console → Data Flows → Stand-alone
4. Batcht 500 berichten of elke 30 seconden — kost < $1/maand

### BigQuery ML scripts

| Bestand | Wat het doet |
|---------|-------------|
| `bigquery/01-create-tables.sql` | BigQuery tabellen aanmaken |
| `bigquery/02-solar-forecast.sql` | Solar yield voorspellen (ARIMA_PLUS) |
| `bigquery/03-anomaly-detection.sql` | Anomaly detection op machine data |
| `bigquery/04-weather-regression.sql` | Weer → solar yield regressie |

### Data exports (CSV → BigQuery upload)

| Bestand | Rijen | Inhoud |
|---------|-------|--------|
| `bigquery/solar_pivoted_1min.csv` | ~4.400 | Solar power per minuut |
| `bigquery/weather_pivoted_5min.csv` | ~900 | Weer per 5 minuten |
| `bigquery/machine_pivoted_1min.csv` | ~4.000 | Machine runtime per minuut |

#### Setup zelf draaien

1. Maak een GCP project aan (gratis tier)
2. BigQuery Console → dataset `uns_cursus` aanmaken
3. `01-create-tables.sql` uitvoeren
4. CSV's uploaden naar de tabellen
5. Demo queries uitvoeren (02, 03, 04)

### Drie demo's

| # | Use case | Model | Data |
|---|----------|-------|------|
| 1 | Hoeveel stroom leveren mijn panelen morgen? | ARIMA_PLUS forecast | Solar yield (kWh) |
| 2 | Draait mijn machine normaal? | Anomaly detection | Machine runtimes |
| 3 | Welk weer bepaalt mijn opbrengst? | Linear regression | Weer + solar |
