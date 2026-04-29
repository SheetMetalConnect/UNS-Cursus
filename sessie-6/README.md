# Sessie 6 — AI-integratie & Data naar de Cloud

## Bestanden

### BigQuery ML

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

## BigQuery setup

1. Maak een GCP project aan (gratis tier)
2. BigQuery Console → dataset `uns_cursus` aanmaken
3. `01-create-tables.sql` uitvoeren
4. CSV's uploaden naar de tabellen
5. Demo queries uitvoeren (02, 03, 04)

## Drie demo's

| # | Use case | Model | Data |
|---|----------|-------|------|
| 1 | Hoeveel stroom leveren mijn panelen morgen? | ARIMA_PLUS forecast | Solar yield (kWh) |
| 2 | Draait mijn machine normaal? | Anomaly detection | Machine runtimes |
| 3 | Welk weer bepaalt mijn opbrengst? | Linear regression | Weer + solar |

## UNS → BigQuery Bridge

Live streaming van UNS data naar BigQuery via Benthos/Redpanda Connect.

| Bestand | Wat het doet |
|---------|-------------|
| `flows/uns-to-bigquery.yaml` | Stand-alone dataflow: UNS → BigQuery |

### Setup

1. Service account key op de UMH server plaatsen
2. `GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json` instellen
3. Flow deployen via Management Console → Data Flows → Stand-alone
4. Batcht 500 berichten of elke 30 seconden — kost < $1/maand

## MCP Servers (Claude Desktop integratie)

| Server | Wat het doet |
|--------|-------------|
| `mcp-servers/uns-timescaledb` | Claude bevraagt je fabrieksdatabase |
| `mcp-servers/uns-mqtt` | Claude publiceert/leest MQTT berichten |

Setup: zie `mcp-servers/README.md`

### Claude Desktop config

```json
{
  "mcpServers": {
    "uns-timescaledb": {
      "command": "uv",
      "args": ["--directory", "<pad-naar-repo>/mcp-servers/uns-timescaledb", "run", "src/server.py"],
      "env": { "DATABASE_URL": "postgresql://grafanareader:changeme@localhost:5432/umh" }
    },
    "uns-mqtt": {
      "command": "uv",
      "args": ["--directory", "<pad-naar-repo>/mcp-servers/uns-mqtt", "run", "src/server.py"],
      "env": { "MQTT_HOST": "localhost", "MQTT_PORT": "1883" }
    }
  }
}
```

### Voorbeeldvragen voor Claude Desktop

- "Welke assets heb ik in mijn fabriek?"
- "Toon de laatste 10 sensormetingen van de machining lijn"
- "Hoeveel werkorders staan er open en welke hebben prioriteit 1?"
- "Wat is de gemiddelde cyclustijd van de afgelopen 24 uur?"
- "Publiceer een test werkorder naar MQTT"
