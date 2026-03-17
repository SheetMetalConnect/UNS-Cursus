# UNS Cursus — Sessie 2: Demo Plan

## Doel

Twee live MQTT databronnen verbinden met de Unified Namespace via UMH Core,
en aantonen hoe het ISA-95 asset model werkt voor het opslaan van industriele
tijdreeksdata in TimescaleDB.

---

## Architectuur

```
  [Tasmota Sensors]           [MetalFab Simulator]
   192.168.68.56:1883          95.217.14.139:1883
        |                            |
        v                            v
  +------------------------------------------+
  |           UMH Core (v0.44.11)            |
  |                                          |
  |  Bridge 1: tasmota-energy                |
  |    MQTT -> tag_processor -> UNS          |
  |                                          |
  |  Bridge 2: metalfab-simulator            |
  |    MQTT -> tag_processor -> UNS          |
  |                                          |
  |  Standalone: historian                   |
  |    UNS _raw -> TimescaleDB              |
  +------------------------------------------+
        |                            |
        v                            v
  +------------------------------------------+
  |  TimescaleDB                             |
  |                                          |
  |  asset table (ISA-95 hierarchy)          |
  |  tag table (numeric hypertable)          |
  |  tag_string table (text hypertable)      |
  +------------------------------------------+
        |
        v
  +------------------------------------------+
  |  Grafana Dashboards                      |
  +------------------------------------------+
```

---

## Demo #1: Tasmota Energy Sensors (Home Lab)

### Bron
- **Broker:** 192.168.68.56:1883 (home lab, geen auth)
- **Topic:** `tele/smc/hq/tasmota/+/SENSOR`
- **Devices:** cabinet, siderack, desk (Tasmota power monitors met energiemeting)
- **Payload:** JSON met `ANALOG.Temperature`, `ENERGY.Power`, `ENERGY.Voltage`, etc.

### Waarom deze demo?
- Laat zien hoe je **niet-UMH MQTT data** (Tasmota formaat) omzet naar het UMH datamodel
- De tag_processor parseert het JSON en maakt **losse tags** per datapunt
- Elk device krijgt automatisch een **eigen asset** in de ISA-95 hierarchy

### Bridge configuratie (Protocol Converter UI)

**General tab:**
- Name: `tasmota-energy`
- Connection: `192.168.68.56:1883`
- Location: `smc.hq` (wordt `{{ .location_path }}` in de tag processor)

**Read tab:**
- Protocol: MQTT
- Data Type: Time Series
- Topic: `tele/smc/hq/tasmota/+/SENSOR`

**Tag Processor — Always (defaults):**
```javascript
msg.meta.location_path = "{{ .location_path }}";
msg.meta.data_contract = "_raw";
msg.meta.tag_name = "sensor";
return msg;
```

**Tag Processor — Advanced Processing:**
```javascript
let topic_parts = (msg.meta["mqtt_topic"] || "").split("/");
let device = topic_parts[4] || "unknown";
let data = typeof msg.payload === "string" ? JSON.parse(msg.payload) : msg.payload;

let base_meta = {
  location_path: msg.meta.location_path + ".tasmota." + device,
  data_contract: "_raw",
  timestamp_ms: Date.now().toString()
};

let messages = [];

// Temperature (Celsius)
if (data.ANALOG && data.ANALOG.Temperature !== undefined) {
  messages.push({
    payload: data.ANALOG.Temperature,
    meta: Object.assign({}, base_meta, { tag_name: "temperature" })
  });
}

// Active Power (Watt)
if (data.ENERGY && data.ENERGY.Power !== undefined) {
  messages.push({
    payload: data.ENERGY.Power,
    meta: Object.assign({}, base_meta, { tag_name: "power" })
  });
}

// Voltage (Volt)
if (data.ENERGY && data.ENERGY.Voltage !== undefined) {
  messages.push({
    payload: data.ENERGY.Voltage,
    meta: Object.assign({}, base_meta, { tag_name: "voltage" })
  });
}

return messages;
```

### Resultaat in UNS (Topic Browser)
```
umh.v1.smc.hq.tasmota.cabinet._raw.temperature   = 30.0
umh.v1.smc.hq.tasmota.cabinet._raw.power          = 0
umh.v1.smc.hq.tasmota.cabinet._raw.voltage         = 206
umh.v1.smc.hq.tasmota.siderack._raw.temperature   = 29.7
umh.v1.smc.hq.tasmota.siderack._raw.power          = 0
umh.v1.smc.hq.tasmota.siderack._raw.voltage         = 121
umh.v1.smc.hq.tasmota.desk._raw.temperature        = 30.0
umh.v1.smc.hq.tasmota.desk._raw.power               = 125
umh.v1.smc.hq.tasmota.desk._raw.voltage              = 231
```

### Assets in TimescaleDB
| enterprise | site | area    | line      | workcell | Beschrijving |
|-----------|------|---------|-----------|----------|-------------|
| smc       | hq   | tasmota | cabinet   |          | Serverkast energiemeter |
| smc       | hq   | tasmota | siderack  |          | Zijkast energiemeter |
| smc       | hq   | tasmota | desk      |          | Bureau energiemeter |

---

## Demo #2: MetalFab Simulator (Cloud)

### Bron
- **Broker:** 95.217.14.139:1883 (cloud server, geen auth)
- **Topic:** `umh/v1/metalfab/eindhoven/+/+/_raw/#`
- **Machines:** laser_01, press_brake_01, robot_weld_01, etc.
- **Payload:** Bare numeric/string values (al in UMH `_raw` formaat)

### Waarom deze demo?
- Laat zien hoe je data **van een externe UMH broker** bridget
- De data is al in UMH formaat — de tag_processor hoeft alleen de locatie te mappen
- Toont een **grotere fabriek** met meerdere afdelingen en machines
- Zelfde historian flow schrijft alles naar dezelfde TimescaleDB — bewijst schaalbaarheid

### Bridge configuratie (Protocol Converter UI)

**General tab:**
- Name: `metalfab-simulator`
- Connection: `95.217.14.139:1883`
- Location: `metalfab.eindhoven`

**Read tab:**
- Protocol: MQTT
- Data Type: Time Series
- Topics (beperkt tot 2 machines om de demo beheersbaar te houden):
  - `umh/v1/metalfab/eindhoven/cutting/laser_01/_raw/#`
  - `umh/v1/metalfab/eindhoven/forming/press_brake_01/_raw/#`

**Tag Processor — Always (defaults):**
```javascript
let topic_parts = (msg.meta["mqtt_topic"] || "").split("/");
// umh/v1/metalfab/eindhoven/cutting/laser_01/_raw/laser_power
//  [0] [1]  [2]      [3]     [4]     [5]    [6]    [7...]

msg.meta.location_path = topic_parts.slice(2, 6).join(".");
msg.meta.data_contract = "_raw";
msg.meta.tag_name = topic_parts.slice(7).join(".");
msg.meta.timestamp_ms = Date.now().toString();
return msg;
```

### Resultaat in UNS (Topic Browser)
```
umh.v1.metalfab.eindhoven.cutting.laser_01._raw.laser_power    = 85.5
umh.v1.metalfab.eindhoven.cutting.laser_01._raw.state           = 3
umh.v1.metalfab.eindhoven.cutting.laser_01._raw.infeed          = 42
umh.v1.metalfab.eindhoven.forming.press_brake_01._raw.tonnage   = 150
umh.v1.metalfab.eindhoven.forming.press_brake_01._raw.bend_angle = 90
```

### Assets in TimescaleDB
| enterprise | site      | area     | line           | Beschrijving |
|-----------|-----------|----------|----------------|-------------|
| metalfab  | eindhoven | cutting  | laser_01       | Laser snijmachine |
| metalfab  | eindhoven | forming  | press_brake_01 | Kantbank |

---

## Waarom het Asset Model belangrijk is

### Het probleem zonder assets
Als je alle sensordata in 1 platte tabel gooit, krijg je:
- Geen context: "power = 125" — van welke machine?
- Geen filtering: je kunt niet filteren op afdeling of locatie
- Geen schaalbaarheid: 1 miljoen rijen zonder structuur

### De ISA-95 oplossing
Het asset model volgt de ISA-95 standaard (enterprise → site → area → line → workcell):

```
smc (enterprise)
└── hq (site)
    └── tasmota (area)
        ├── cabinet (line)     → temperature, power, voltage
        ├── siderack (line)    → temperature, power, voltage
        └── desk (line)        → temperature, power, voltage

metalfab (enterprise)
└── eindhoven (site)
    ├── cutting (area)
    │   └── laser_01 (line)    → laser_power, state, infeed, ...
    └── forming (area)
        └── press_brake_01     → tonnage, bend_angle, ...
```

### Voordelen
1. **Elke tag hoort bij een asset** — je weet altijd van welke machine de data komt
2. **Hierarchisch filteren** — alle data van "eindhoven", of alleen "cutting"
3. **Zelfde schema voor alles** — sensoren, ERP-data, kwaliteitsdata
4. **Auto-creatie** — `get_asset_id()` maakt assets automatisch aan bij eerste datapunt
5. **Grafana queries** — `WHERE asset_id = X` is razendsnel door indexering

### Werkt ook voor ERP data
Later kunnen we dezelfde structuur gebruiken voor work orders, sales orders, etc.
Het asset model is de ruggengraat van de hele Unified Namespace.

---

## Historian Flow (UNS → TimescaleDB)

De historian flow luistert naar ALLE `_raw` data in de UNS en schrijft het naar
TimescaleDB. Eenmaal deployed werkt het voor beide demo's automatisch.

### Deploy via Management Console
1. Ga naar Data Flows → Stand-alone → Add
2. Plak de 3 secties uit `examples/databridges/flows/historian.yaml`
3. Save & Deploy

### Wat het doet
```
UNS: umh.v1.smc.hq.tasmota.desk._raw.power = 125
                    ↓
        historian flow (bloblang)
                    ↓
        get_asset_id('smc','hq','tasmota','desk','','')
                    ↓
        INSERT INTO tag (time, asset_id, tag_name, value, origin)
        VALUES (NOW(), 4, 'power', 125, 'uns')
```

---

## Deployment Volgorde

1. **Stack starten:** `docker compose up -d`
2. **Bridge 1:** Tasmota energy (Protocol Converter via UI)
3. **Verify:** Topic Browser — zie je de 9 tags?
4. **Bridge 2:** MetalFab simulator (Protocol Converter via UI)
5. **Verify:** Topic Browser — zie je de simulator tags?
6. **Historian:** Deploy standalone flow
7. **Verify:** `SELECT * FROM tag ORDER BY time DESC LIMIT 10;`
8. **Dashboard:** Grafana (optioneel, als er tijd is)

---

## Troubleshooting

```bash
# Container status
docker ps

# UMH Core logs
docker compose logs umh -f

# Check TimescaleDB
docker exec timescaledb psql -U postgres -d umh -c "SELECT * FROM asset;"
docker exec timescaledb psql -U postgres -d umh -c "SELECT * FROM tag ORDER BY time DESC LIMIT 10;"

# Test MQTT verbinding
mosquitto_sub -h 192.168.68.56 -p 1883 -t "tele/smc/hq/tasmota/+/SENSOR" -v
mosquitto_sub -h 95.217.14.139 -p 1883 -t "umh/v1/metalfab/eindhoven/cutting/laser_01/_raw/#" -v
```

---

## Stack Configuratie

| Service     | Port | Login              |
|-------------|------|--------------------|
| Grafana     | 3000 | admin / changeme   |
| Node-RED    | 1880 | (geen login)       |
| Portainer   | 9000 | (setup bij eerste keer) |
| TimescaleDB | 5432 | postgres / changeme |
| HiveMQ MQTT | 1883 | (geen auth)        |
| UMH Core    | —    | via Management Console |
