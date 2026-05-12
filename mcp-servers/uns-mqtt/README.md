# uns-mqtt — MCP Server

MCP server waarmee Claude berichten kan lezen en publiceren op de MQTT broker (HiveMQ) van de UNS.

## Wat kan het?

| Tool | Omschrijving |
|------|-------------|
| `mqtt_publish` | Publiceer een bericht naar een MQTT topic (scope-guarded) |
| `mqtt_subscribe` | Subscribe op een topic en verzamel berichten |
| `mqtt_list_topics` | Toon alle actieve topics op de broker |

**Resources:** `uns://broker-info` (broker configuratie + agent identiteit)

**Achtergrond:**
- **Heartbeat**: elke 10s wordt een status-bericht gepubliceerd op `umh/v1/smc/agents/{AGENT_NAME}/_status`. State wisselt tussen `idle` en `processing`. Bij shutdown wordt een retained `offline` bericht gepubliceerd.
- **Topic cache**: een achtergrond-listener subscribet op `#` om alle gezien topics in een cache bij te houden.

## Installatie

### Vereisten
- Python 3.10+
- `uv` (Python package manager)
- De UNS stack moet draaien (`docker compose up -d` in /stack)

### Stap 1 — Installeer dependencies

```bash
cd mcp-servers/uns-mqtt
uv sync
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
        "UNS_MQTT_PORT": "1883",
        "AGENT_NAME": "luke-agent",
        "AGENT_PUBLISH_PREFIX": "umh/v1/smc/agents/luke-agent/",
        "AGENT_PUBLISH_ALLOW_PRODUCTION": "false"
      }
    }
  }
}
```

Vervang `/VOLLEDIG/PAD/NAAR/` door het daadwerkelijke pad op je laptop.

Herstart Claude Desktop.

## Heartbeat

Zodra de server draait, publishet hij elke 10s zijn status:

**Topic:** `umh/v1/smc/agents/{AGENT_NAME}/_status`

**Payload:**
```json
{
  "agent": "luke-agent",
  "state": "idle",
  "ts": "2026-05-12T09:03:19.119585+00:00",
  "uptime_s": 30,
  "version": "0.1.0"
}
```

`state` is `idle` als de agent niets doet, `processing` tijdens een tool-aanroep, en `offline` (retained) bij shutdown.

Verifiëren met `mosquitto_sub`:
```bash
mosquitto_sub -h localhost -t 'umh/v1/smc/agents/+/_status' -v
```

## Scope guard

`mqtt_publish` accepteert alleen topics binnen `AGENT_PUBLISH_PREFIX`. Buiten die scope krijgt de LLM een nette error string terug:

```
PUBLISH_DENIED: topic 'umh/v1/smc/vienna/cnc-1/temperature' outside agent scope 'umh/v1/smc/agents/luke-agent/'. Allowed: umh/v1/smc/agents/luke-agent/#
```

Voor een demo waar de agent op de hele UNS mag schrijven, zet `AGENT_PUBLISH_ALLOW_PRODUCTION=true`. Dan is alles binnen `umh/v1/smc/#` toegestaan.

`mqtt_subscribe` en `mqtt_list_topics` zijn niet scope-beperkt — luisteren mag overal.

## Probeer deze prompts

Zodra de server gekoppeld is aan Claude Desktop, probeer:

- **"Welke MQTT topics zijn er actief?"** — mqtt_list_topics
- **"Luister 10 seconden naar umh/v1/# en vertel wat er gebeurt"** — mqtt_subscribe
- **"Publiceer een notitie op je eigen status-tree"** — mqtt_publish (binnen scope)
- **"Monitor de productie en geef een live rapport"** — gebruikt subscribe + list_topics

## Let op

De MQTT server start een achtergrond-listener op alle topics (`#`). Hiermee wordt een cache opgebouwd van alle actieve topics. Dit kan even duren bij eerste opstart — wacht ~10 seconden voordat je `mqtt_list_topics` gebruikt.

## Configuratie

| Env variabele | Default | Omschrijving |
|---------------|---------|-------------|
| `UNS_MQTT_HOST` | `localhost` | MQTT broker hostname |
| `UNS_MQTT_PORT` | `1883` | MQTT broker port |
| `UNS_MQTT_LOG_LEVEL` | `INFO` | Logging level (`DEBUG` toont elke heartbeat) |
| `AGENT_NAME` | `luke-agent` | Identiteit voor heartbeat + scope prefix |
| `AGENT_PUBLISH_PREFIX` | `umh/v1/smc/agents/{AGENT_NAME}/` | Scope waar `mqtt_publish` mag schrijven |
| `AGENT_PUBLISH_ALLOW_PRODUCTION` | `false` | Indien `true`: publishes mogen op heel `umh/v1/smc/#` |

De HiveMQ broker in de stack draait zonder authenticatie (`HIVEMQ_ALLOW_ALL_CLIENTS=true`).
