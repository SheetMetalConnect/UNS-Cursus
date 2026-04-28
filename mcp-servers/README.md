# MCP Servers — UNS Cursus

Twee MCP (Model Context Protocol) servers waarmee Claude Desktop direct met je UNS stack kan praten.

| Server | Wat doet het |
|--------|-------------|
| [uns-timescaledb](uns-timescaledb/) | Database bevragen — sensordata, werkorders, sales orders |
| [uns-mqtt](uns-mqtt/) | MQTT broker — berichten lezen, publiceren, topics verkennen |

## Wat is MCP?

MCP is een open standaard van Anthropic waarmee AI-modellen tools en data kunnen gebruiken. In plaats van data te copy-pasten naar Claude, geef je Claude direct toegang tot je systemen.

Meer info: https://modelcontextprotocol.io

## Snelle start

### 1. Zorg dat de UNS stack draait

```bash
cd stack
docker compose up -d
```

### 2. Installeer de servers

```bash
# TimescaleDB server
cd mcp-servers/uns-timescaledb
uv venv && uv pip install -e .

# MQTT server
cd ../uns-mqtt
uv venv && uv pip install -e .
```

### 3. Configureer Claude Desktop

Open Claude Desktop > Settings > Developer > Edit Config.

Plak de volgende configuratie in `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "uns-timescaledb": {
      "command": "uv",
      "args": [
        "--directory", "/Users/JOUW_NAAM/Documents/GitHub/UNS-Cursus/mcp-servers/uns-timescaledb",
        "run", "src/server.py"
      ],
      "env": {
        "UNS_DB_DSN": "postgresql://grafanareader:changeme@localhost:5432/umh"
      }
    },
    "uns-mqtt": {
      "command": "uv",
      "args": [
        "--directory", "/Users/JOUW_NAAM/Documents/GitHub/UNS-Cursus/mcp-servers/uns-mqtt",
        "run", "src/server.py"
      ],
      "env": {
        "UNS_MQTT_HOST": "localhost",
        "UNS_MQTT_PORT": "1883"
      }
    }
  }
}
```

Vervang `/Users/JOUW_NAAM/...` door het pad naar jouw checkout van deze repo.

Herstart Claude Desktop.

### 4. Test

Open een nieuw gesprek in Claude Desktop. Je ziet de MCP tools verschijnen (hamertje-icoon). Probeer:

> "Geef een overzicht van mijn fabriek — welke assets zijn er, welke orders staan open, en hoeveel sensordata komt er binnen?"

> "Welke MQTT topics zijn er actief op mijn broker?"

> "Publiceer een test werkorder voor 25 stuks beugels op de CNC machine"

## Testen zonder Claude Desktop

Gebruik de MCP Inspector om de servers los te testen:

```bash
cd mcp-servers/uns-timescaledb
uv run mcp dev src/server.py
# Open http://localhost:6274
```

## Vereisten

- Python 3.10+
- [uv](https://docs.astral.sh/uv/) (Python package manager)
- Docker Desktop met de UNS stack draaiend
- Claude Desktop (of een andere MCP client)

## Architectuur

```
Claude Desktop
    |
    |-- MCP (stdio) --> uns-timescaledb --> TimescaleDB (:5432)
    |
    |-- MCP (stdio) --> uns-mqtt ---------> HiveMQ (:1883)
```

Beide servers draaien lokaal via stdio transport. Claude Desktop start ze automatisch op als child process.
