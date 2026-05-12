# Sessie 6 — AI Agent op de UNS

> **Hoofdles:** AI-agent abonneert op de UNS (MQTT + Kafka via TimescaleDB historian) en chat met de fabriek via MCP.
> **Bijzaak:** BigQuery-upload als korte cloud-demo aan het eind van de sessie.

## Hoofdles — MCP Servers (Claude Desktop praat met je UNS)

Twee MCP-servers laten een AI-agent rechtstreeks met je UNS chatten:

| Server | Wat het doet |
|--------|-------------|
| `mcp-servers/uns-mqtt` | Subscribe, publish, list topics op de HiveMQ broker |
| `mcp-servers/uns-timescaledb` | Sensoren, werkorders, sales orders en custom SQL op de historian |

Setup: zie [`mcp-servers/README.md`](../mcp-servers/README.md).

### Claude Desktop config

Open Claude Desktop → Settings → Developer → Edit Config en plak:

```json
{
  "mcpServers": {
    "uns-timescaledb": {
      "command": "uv",
      "args": ["--directory", "<JOUW-PAD>/UNS-Cursus/mcp-servers/uns-timescaledb", "run", "src/server.py"],
      "env": { "UNS_DB_DSN": "postgresql://grafanareader:changeme@localhost:5432/umh" }
    },
    "uns-mqtt": {
      "command": "uv",
      "args": ["--directory", "<JOUW-PAD>/UNS-Cursus/mcp-servers/uns-mqtt", "run", "src/server.py"],
      "env": { "UNS_MQTT_HOST": "localhost", "UNS_MQTT_PORT": "1883" }
    }
  }
}
```

Vervang `<JOUW-PAD>` door het absolute pad naar je checkout. Herstart Claude Desktop volledig (Quit, niet alleen close).

### Voorbeeldvragen voor Claude Desktop

- "Welke MQTT topics zijn nu actief?"
- "Wat zijn de laatste 5 berichten op `umh.v1.smc.vienna.solar._historian`?"
- "Welke assets heb ik in mijn fabriek?"
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
