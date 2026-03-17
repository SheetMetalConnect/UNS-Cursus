# UNS Cursus — Unified Namespace voor de Maakindustrie

Lesmateriaal voor de UNS cursus van [SheetMetalConnect](https://github.com/SheetMetalConnect).

Leer hoe je een Unified Namespace (UNS) opzet met [UMH Core](https://www.umh.app/) — van MQTT sensoren tot Grafana dashboards.

## Sessies

| Sessie | Onderwerp | Status |
|--------|-----------|--------|
| [Sessie 1](sessie-1/) | Introductie UMH & Unified Namespace | Beschikbaar |
| [Sessie 2](sessie-2/) | MQTT ingestie, TimescaleDB & Grafana | Beschikbaar |

## Wat heb je nodig?

- Docker Desktop ([download](https://www.docker.com/products/docker-desktop/))
- DBeaver Community ([download](https://dbeaver.io/download/))
- MQTT Explorer ([download](https://mqtt-explorer.com/)) — optioneel
- Een teksteditor (VS Code, Notepad++, etc.)

## Stack overzicht

De cursus gebruikt een Docker Compose stack met:

| Component | Doel |
|-----------|------|
| [UMH Core](https://docs.umh.app/) | Unified Namespace hub (Redpanda + dataFlows) |
| [TimescaleDB](https://www.timescale.com/) | Tijdreeks database (PostgreSQL + hypertables) |
| [Grafana](https://grafana.com/) | Dashboards & visualisatie |
| [HiveMQ CE](https://www.hivemq.com/community/) | MQTT broker |
| [Node-RED](https://nodered.org/) | Flow-based programming |

## Snel starten

```bash
git clone https://github.com/SheetMetalConnect/UNS-Cursus.git
cd UNS-Cursus
```

Volg de instructies per sessie.

## Online MQTT broker (cursus)

De cursus-simulator draait 24/7:

```
Broker: 95.217.14.139:1883 (geen login nodig)
Topic:  umh/v1/metalfab/#
```

Verbind met MQTT Explorer of Node-RED om live fabrieksdata te bekijken.

## Licentie

MIT — vrij te gebruiken en aan te passen.
