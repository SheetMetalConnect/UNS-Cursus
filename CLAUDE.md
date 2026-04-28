# UNS Cursus — Project Instructions

This is the GitHub repo for the **UNS Workshop (Cohort 2026)** by SheetMetalConnect. It contains participant-facing materials for a 6-session course teaching metalworking professionals to build a Unified Namespace with UMH Core.

## Language & Tone

- All participant-facing content is **Dutch** (nl-NL)
- Informal professional tone — "je/jij", consultant teaching peers
- Use physical/workshop metaphors (archiefkast, werkplaats, adres)
- Code examples use real MetalFab simulator data, never lorem-ipsum

## Repo Structure

```
sessie-N/
  README.md              # Per-session instructions + exercises
  sql/                   # SQL scripts for TimescaleDB
  flows/                 # Benthos/UMH data bridge YAML configs
  nodered/               # Node-RED flow JSON exports
  demo/                  # Demo data (CSV, etc.)
  grafana/               # Dashboard JSON exports
stack/                   # Shared Docker Compose stack
simulator/               # MetalFab factory simulator
```

## Key Conventions

- **Topic naming:** Always use full UMH path: `umh/v1/enterprise/site/area/line/_contract/tag`
- **ISA-95 hierarchy:** enterprise → site → area → line → workcell — use consistently
- **Protocol bridges** (MQTT, Modbus, OPC-UA) are always deployed as **Bridge**, never Standalone
- **Session folders** contain working configs and exercises; handboeken (PDF) live on Google Drive
- **Never commit draft/incomplete session material** without explicit approval from Luke

## Tech Stack

| Component   | Purpose                     | Port |
|-------------|-----------------------------|------|
| UMH Core    | UNS hub (Redpanda + flows)  | 8443 |
| TimescaleDB | Time-series storage         | 5432 |
| Grafana     | Dashboards                  | 3000 |
| HiveMQ CE   | MQTT broker                 | 1883 |
| Node-RED    | Visual flow programming     | 1880 |

## Safety

- Never hardcode IPs, passwords, or auth tokens — use `.env` and `.env.example`
- Never use client AUTH_TOKENs for course/demo stacks
- The `.env` file is gitignored; only `.env.example` is committed
