# UNS Cursus — Unified Namespace voor de Maakindustrie

Lesmateriaal voor de UNS Workshop van [SheetMetalConnect](https://sheetmetalconnect.com), verzorgd door [Luke van Enkhuizen](https://vanenkhuizen.com).

**Interesse in een volgende cohort?** Neem contact op via [vanenkhuizen.com](https://vanenkhuizen.com) of [sheetmetalconnect.com](https://sheetmetalconnect.com).

## Wat is een Unified Namespace?

In de meeste fabrieken zijn systemen los gekoppeld: een PLC praat met SCADA, SCADA praat met MES, MES praat met ERP — en elke koppeling is maatwerk. Wil je een nieuw dashboard of AI-model? Dan moet je weer een nieuwe verbinding bouwen. Bij 10 systemen heb je al snel 45 koppelingen te onderhouden.

Een **Unified Namespace (UNS)** draait dat om. Elk systeem publiceert zijn data naar een centrale plek, en elk ander systeem kan zich abonneren op precies de data die het nodig heeft. Nieuwe machine? Gewoon aansluiten op de namespace. Nieuw dashboard? Abonneer je op de juiste topics. Geen maatwerk, geen spaghetti-integraties.

## Waarom deze cursus?

Deze workshop is gebouwd voor vakmensen in de maakindustrie — plaatbewerking, verspaning, assemblage — die hun fabriek willen digitaliseren zonder afhankelijk te worden van dure, gesloten platforms. Je leert stap voor stap een UNS opzetten met open-source tooling die je zelf kunt beheren.

Na 6 sessies heb je:
- Een werkende UNS-stack op je eigen laptop
- Sensordata, machinedata en ERP-data op een centrale plek
- Live dashboards die je direct kunt gebruiken op de werkvloer
- Kennis van industriele protocollen (OPC UA, Modbus, MQTT)
- Een architectuur die je kunt meenemen naar je eigen fabriek

## Sessies

| Sessie | Onderwerp | Wat je leert |
|--------|-----------|--------------|
| [Sessie 1](sessie-1/) | UNS Design & Introductie | Wat is een UNS, ISA-95 hierarchy, MQTT basics, UMH Core kennismaking |
| [Sessie 2](sessie-2/) | Docker, TimescaleDB & Grafana | Stack installeren, database opzetten, eerste data opslaan en visualiseren |
| [Sessie 3](sessie-3/) | Industriele Protocollen | OPC UA, Modbus en MQTT bridges configureren — machines aansluiten op de UNS |
| [Sessie 4](sessie-4/) | Grafana Dashboards | Dashboards bouwen met echte machinedata, ERP-data ophalen via polling |
| [Sessie 5](sessie-5/) | ERP- & MES-integratie | Data bridges, deduplicatie, audit trail — non-event-driven systemen event-driven maken |
| [Sessie 6](sessie-6/) | AI-integratie & Data naar de Cloud | Binnenkort |

## Wat heb je nodig?

- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- [DBeaver Community](https://dbeaver.io/download/)
- Een teksteditor (VS Code, Notepad++, etc.)
- [MQTT Explorer](https://mqtt-explorer.com/) (optioneel, handig voor debugging)

## Stack

De cursus gebruikt een Docker Compose stack die je lokaal draait:

| Component | Doel | Poort |
|-----------|------|-------|
| [UMH Core](https://docs.umh.app/) | UNS hub (Redpanda + dataflows) | 8443 |
| [TimescaleDB](https://www.timescale.com/) | Tijdreeks database | 5432 |
| [Grafana](https://grafana.com/) | Dashboards | 3000 |
| [HiveMQ CE](https://www.hivemq.com/community/) | MQTT broker | 1883 |
| [Node-RED](https://nodered.org/) | Flow-based programming | 1880 |

```bash
cd stack
cp .env.example .env   # vul je AUTH_TOKEN in
docker compose up -d
```

## Simulator

De `simulator/` map bevat een MetalFab fabriekssimulator die MQTT, OPC-UA, Modbus en HTTP API data genereert — dezelfde databronnen die je in een echte fabriek tegenkomt. Zie [`simulator/README.md`](simulator/README.md) voor instructies.

## Licentie

MIT — vrij te gebruiken en aan te passen.
