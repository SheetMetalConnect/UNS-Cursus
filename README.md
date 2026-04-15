# UNS Cursus — Unified Namespace voor de Maakindustrie

Lesmateriaal voor de UNS cursus van [SheetMetalConnect](https://sheetmetalconnect.com).

Leer hoe je een Unified Namespace (UNS) opzet met [UMH Core](https://www.umh.app/) — van sensoren tot dashboards.

## Sessies

| Sessie | Onderwerp | Status |
|--------|-----------|--------|
| [Sessie 1](sessie-1/) | Introductie UMH & Unified Namespace | Beschikbaar |
| [Sessie 2](sessie-2/) | Docker, TimescaleDB & Grafana | Beschikbaar |
| [Sessie 3](sessie-3/) | OPC UA, Modbus & Industriele Protocollen | Beschikbaar |
| [Sessie 4](sessie-4/) | Grafana Dashboards & ERP-integratie | Beschikbaar |
| [Sessie 5](sessie-5/) | Binnenkort | |
| [Sessie 6](sessie-6/) | Binnenkort | |

## Wat heb je nodig?

- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- [DBeaver Community](https://dbeaver.io/download/)
- Een teksteditor (VS Code, Notepad++, etc.)

## Stack

De cursus gebruikt een Docker Compose stack:

| Component | Doel | Poort |
|-----------|------|-------|
| [UMH Core](https://docs.umh.app/) | UNS hub (Redpanda + dataflows) | — |
| [TimescaleDB](https://www.timescale.com/) | Tijdreeks database | 5432 |
| [Grafana](https://grafana.com/) | Dashboards | 3000 |
| [HiveMQ CE](https://www.hivemq.com/community/) | MQTT broker | 1883 |
| [Node-RED](https://nodered.org/) | Flow-based programming | 1880 |

```bash
cd stack
cp .env.example .env   # vul AUTH_TOKEN in
docker compose up -d
```

## Simulator

De `simulator/` map bevat een MetalFab fabriekssimulator met MQTT, OPC-UA, Modbus en HTTP API databronnen. Zie `simulator/README.md` voor instructies.

## Licentie

MIT — vrij te gebruiken en aan te passen.
