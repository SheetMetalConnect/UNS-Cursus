# Sessie 3 — Protocollen & Bridges

## Simulator

```
MQTT:      95.217.14.139:1883 (geen auth)
OPC-UA:    opc.tcp://95.217.14.139:4840 (anonymous)
Modbus:    95.217.14.139:5020 (Slave ID 1)
Weer API:  http://95.217.14.139:8084/api/weather/current
```

Of draai de simulator lokaal: zie `simulator/`.

## Flows

| Bestand | Protocol | Deploy als |
|---------|----------|-----------|
| `flows/historian.yaml` | UNS → SQL | Standalone |
| `flows/mqtt-metalfab.yaml` | MQTT | Bridge |
| `flows/laser-demonstratie.yaml` | OPC-UA | Bridge |
| `flows/ontbraam.yaml` | OPC-UA | Bridge |
| `flows/modbus-solar-bridge.yaml` | Modbus | Bridge of Standalone |
| `flows/weather-bridge.yaml` | HTTP polling | Standalone |
| `flows/stroomkosten.yaml` | HTTP polling | Standalone |

OPC-UA node mappings: `tags/opcua_nodes.csv` (Import CSV in de Bridge UI).
