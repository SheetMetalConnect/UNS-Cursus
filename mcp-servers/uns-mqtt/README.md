# uns-mqtt — MCP Server

MCP server waarmee Claude berichten kan lezen en publiceren op de MQTT broker (HiveMQ) van de UNS.

## Wat kan het?

| Tool | Omschrijving |
|------|-------------|
| `mqtt_publish` | Publiceer een bericht naar een MQTT topic |
| `mqtt_subscribe` | Subscribe op een topic en verzamel berichten |
| `mqtt_list_topics` | Toon alle actieve topics op de broker |

**Resources:** `uns://broker-info` (broker configuratie en topic structuur)

## Installatie

### Vereisten
- Python 3.10+
- `uv` (Python package manager)
- De UNS stack moet draaien (`docker compose up -d` in /stack)

### Stap 1 — Installeer dependencies

```bash
cd mcp-servers/uns-mqtt
uv venv
uv pip install -e .
```

### Stap 2 — Test de server

```bash
# Test met de MCP Inspector
uv run mcp dev src/server.py
```

Open http://localhost:6274 en test de tools.

### Stap 3 — Koppel aan Claude Desktop

Open Claude Desktop > Settings > Developer > Edit Config.

Voeg toe aan `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "uns-mqtt": {
      "command": "uv",
      "args": [
        "--directory", "/VOLLEDIG/PAD/NAAR/mcp-servers/uns-mqtt",
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

Vervang `/VOLLEDIG/PAD/NAAR/` door het daadwerkelijke pad op je laptop.

Herstart Claude Desktop.

## Probeer deze prompts

Zodra de server gekoppeld is aan Claude Desktop, probeer:

- **"Welke MQTT topics zijn er actief?"** — mqtt_list_topics
- **"Luister 10 seconden naar umh/v1/# en vertel wat er gebeurt"** — mqtt_subscribe
- **"Publiceer een test werkorder WO-TEST-001"** — mqtt_publish
- **"Monitor de productie en geef een live rapport"** — gebruikt subscribe + list_topics
- **"Stuur een werkorder voor 50 stuks product X naar de CNC"** — publish met JSON payload

## Let op

De MQTT server start een achtergrond-listener op alle topics (`#`). Hiermee wordt een cache opgebouwd van alle actieve topics. Dit kan even duren bij eerste opstart — wacht ~10 seconden voordat je `mqtt_list_topics` gebruikt.

## Configuratie

| Env variabele | Default | Omschrijving |
|---------------|---------|-------------|
| `UNS_MQTT_HOST` | `localhost` | MQTT broker hostname |
| `UNS_MQTT_PORT` | `1883` | MQTT broker port |

De HiveMQ broker in de stack draait zonder authenticatie (`HIVEMQ_ALLOW_ALL_CLIENTS=true`).
