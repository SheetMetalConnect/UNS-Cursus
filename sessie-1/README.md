# Sessie 1 — Introductie UMH & Unified Namespace

## Leerdoelen

- Begrijpen wat een Unified Namespace (UNS) is en waarom het belangrijk is
- Kennismaken met UMH Core als platform
- De ISA-95 hierarchy begrijpen (enterprise → site → area → line → workcell)
- MQTT basics: topics, publish/subscribe, QoS

## Wat is een Unified Namespace?

Een UNS is een centrale plek waar **alle** data van je organisatie samenkomt — van sensoren op de werkvloer tot ERP-systemen. Elke databron publiceert naar dezelfde namespace, en elke consumer kan zich abonneren op precies de data die het nodig heeft.

**Traditioneel (point-to-point):**
```
PLC ──── SCADA
PLC ──── MES ──── ERP
Sensor ──── Database
```
Elke nieuwe verbinding = nieuwe integratie. N systemen = N² verbindingen.

**Met een UNS:**
```
PLC ────┐
Sensor ─┤
MES ────┤──→ UNS ──→ Dashboard
ERP ────┤          ──→ Database
Camera ─┘          ──→ AI/ML
```
Elke bron publiceert 1x. Elke consumer abonneert zich. N systemen = N verbindingen.

## Waarom UMH Core?

[United Manufacturing Hub](https://www.umh.app/) (UMH) is een open-source platform speciaal gebouwd voor de maakindustrie:

- **Management Console** — web UI om bridges, flows en data te beheren
- **Protocol support** — OPC UA, Modbus, S7, MQTT, HTTP, en meer
- **UNS ingebouwd** — Redpanda (Kafka-compatible) als backbone
- **Data contracts** — `_raw` voor ongevalideerde data, custom contracts voor gestructureerde data
- **Topic Browser** — live overzicht van alle data in je namespace
- **Docker-based** — draait overal, geen Kubernetes nodig

## ISA-95 Hierarchy

UMH organiseert data volgens de ISA-95 standaard:

```
umh/v1/{enterprise}/{site}/{area}/{line}/{workcell}/_raw/{tag_name}
```

Voorbeeld:
```
umh/v1/metalfab/eindhoven/cutting/laser_01/_raw/laser_power = 85.5
       ├─enterprise─┤├──site──┤├─area──┤├─line──┤      ├─tag──┤
```

Dit geeft je:
- Automatische hiërarchie: alle data van "eindhoven" met 1 filter
- Schaalbaar: nieuwe machine = nieuw level in de boom
- Gestandaardiseerd: iedereen gebruikt dezelfde structuur

## MQTT Basics

MQTT (Message Queuing Telemetry Transport) is het standaard protocol voor IoT:

| Concept | Uitleg |
|---------|--------|
| **Broker** | Centrale server die berichten routeert |
| **Topic** | Adres van een bericht (bijv. `umh/v1/metalfab/eindhoven/...`) |
| **Publish** | Bericht sturen naar een topic |
| **Subscribe** | Luisteren naar een topic (wildcards: `+` = 1 level, `#` = alles) |
| **QoS 0** | Fire and forget |
| **QoS 1** | Minstens 1x afgeleverd |
| **Retain** | Laatste bericht bewaard voor nieuwe subscribers |

## Bronnen

- [UMH Documentatie](https://docs.umh.app/)
- [UMH Getting Started](https://docs.umh.app/getting-started/)
- [UMH Management Console](https://management.umh.app/)
- [ISA-95 Wikipedia](https://en.wikipedia.org/wiki/ANSI/ISA-95)
- [MQTT Specification](https://mqtt.org/)
- [HiveMQ MQTT Essentials](https://www.hivemq.com/mqtt-essentials/)

## Huiswerk voor sessie 2

1. Installeer [Docker Desktop](https://www.docker.com/products/docker-desktop/)
2. Installeer [DBeaver Community](https://dbeaver.io/download/)
3. Optioneel: installeer [MQTT Explorer](https://mqtt-explorer.com/)
4. Verbind met de cursus broker (`<cloud-broker>:1883`) via MQTT Explorer en bekijk de data op `umh/v1/metalfab/#`
