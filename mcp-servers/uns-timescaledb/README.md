# uns-timescaledb — MCP Server

MCP server waarmee Claude je UNS historian database (TimescaleDB) kan bevragen.

## Wat kan het?

| Tool | Omschrijving |
|------|-------------|
| `query_sensors` | Sensordata opvragen (tag tabel) — filter op asset, tag_name, tijdsperiode |
| `query_work_orders` | Werkorders opvragen (huidige staat) |
| `query_work_order_history` | Audit trail van werkorder-wijzigingen |
| `query_sales_orders` | Sales orders opvragen |
| `list_assets` | Alle assets in de ISA-95 hiërarchie |
| `query_custom` | Eigen SQL query draaien (read-only) |

**Resources:** `uns://schema` (database structuur), `uns://assets` (asset lijst)

## Installatie

### Vereisten
- Python 3.10+
- `uv` (Python package manager)
- De UNS stack moet draaien (`docker compose up -d` in /stack)

### Stap 1 — Installeer dependencies

```bash
cd mcp-servers/uns-timescaledb
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
    "uns-timescaledb": {
      "command": "uv",
      "args": [
        "--directory", "/VOLLEDIG/PAD/NAAR/mcp-servers/uns-timescaledb",
        "run", "src/server.py"
      ],
      "env": {
        "UNS_DB_DSN": "postgresql://grafanareader:changeme@localhost:5432/umh"
      }
    }
  }
}
```

Vervang `/VOLLEDIG/PAD/NAAR/` door het daadwerkelijke pad op je laptop.

Herstart Claude Desktop.

## Probeer deze prompts

Zodra de server gekoppeld is aan Claude Desktop, probeer:

- **"Geef een overzicht van de fabriek"** — gebruikt meerdere tools voor een totaalbeeld
- **"Welke werkorders staan open?"** — query_work_orders
- **"Toon de sensordata van de laatste 4 uur voor cnc-1"** — query_sensors
- **"Wat is er gebeurd met werkorder WO-001?"** — query_work_order_history
- **"Hoeveel metingen zijn er vandaag binnengekomen?"** — query_custom met een COUNT query

## Configuratie

| Env variabele | Default | Omschrijving |
|---------------|---------|-------------|
| `UNS_DB_DSN` | `postgresql://grafanareader:changeme@localhost:5432/umh` | PostgreSQL connection string |

De server gebruikt de `grafanareader` user (read-only). INSERT/UPDATE/DELETE queries worden geweigerd.
