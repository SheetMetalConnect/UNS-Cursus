# Sessie 3 — OPC UA, Modbus & Industriele Protocollen

## Leerdoelen

- Begrijpen wat OPC UA is en waarom het de "standaard" van de industrie heet
- Kennen van de problemen met OPC UA in de praktijk
- Modbus begrijpen als alternatief voor oudere machines
- Verschillende sensortypen en hun protocollen kennen
- Weten hoe UMH Core deze protocollen naar de UNS brengt

---

## Het Protocollen Landschap

```
                    ┌─────────────────────────────┐
   Kantoor/IT       │  ERP, MES, SCADA            │  REST, SQL, MQTT
                    └──────────────┬──────────────┘
                                   │
                    ┌──────────────┴──────────────┐
   OT Gateway       │  UMH Core / Protocol Conv.  │  Vertaalt alles → UNS
                    └──────────────┬──────────────┘
                                   │
          ┌────────────┬───────────┼───────────┬────────────┐
          │            │           │           │            │
       OPC UA       Modbus      MQTT        S7comm      HTTP
          │            │           │           │            │
      Moderne CNC   Oude PLC    Sensoren   Siemens PLC   REST API
```

| Protocol | Typisch gebruik | Leeftijd |
|----------|----------------|----------|
| **OPC UA** | Moderne CNC, robots, nieuwe PLC's | 2008+ |
| **Modbus TCP** | Energiemeters, VFD's, oudere PLC's | 1979 (!) |
| **Modbus RTU** | Serieel (RS-485), zeer oude apparatuur | 1979 |
| **MQTT** | IoT sensoren, Tasmota, Shelly | 1999+ |
| **S7comm** | Siemens S7-300/400/1200/1500 | 1990s+ |
| **HTTP/REST** | Cloud APIs, webhooks, moderne sensoren | 2000+ |
| **EtherNet/IP** | Allen-Bradley/Rockwell PLC's | 2001+ |
| **PROFINET** | Siemens ecosysteem | 2004+ |

---

## OPC UA — De Belofte

OPC UA (Open Platform Communications Unified Architecture) werd ontworpen als **de** universele industriele standaard:

### Wat OPC UA belooft
- **Platform-onafhankelijk** — draait op alles, van embedded tot cloud
- **Beveiligd** — certificaten, encryptie, authenticatie ingebouwd
- **Informatie model** — niet alleen data, maar ook structuur en betekenis
- **Discovery** — automatisch servers vinden op het netwerk
- **Historisch** — ingebouwde historian functionaliteit
- **Companion Specifications** — standaard modellen per machinetype (Euromap, PackML, etc.)

### Klinkt perfect... toch?

---

## Wat er mis is met OPC UA in de praktijk

### 1. Vendor Lock-in via Licenties

Het grootste probleem: OPC UA **servers** zitten in de machine, en de fabrikant bepaalt wat je mag lezen.

| Probleem | Voorbeeld |
|----------|-----------|
| **Betaalde licentie** | Trumpf, DMG Mori, Mazak vragen €5.000-€25.000+ per machine voor OPC UA toegang |
| **Feature-gated** | OPC UA server zit in de machine maar is "niet geactiveerd" — betaal extra |
| **Beperkte nodeset** | Je mag 10 van de 500 variabelen lezen, rest is "premium" |
| **Verplichte gateway** | Sommige fabrikanten eisen hun eigen gateway software (extra licentie) |
| **Firmware lock** | OPC UA alleen beschikbaar op nieuwste firmware, upgrade kost ook geld |

> **De ironie:** Een "open" standaard die fabrikanten gebruiken als verdienmodel.

### 2. Complexiteit

- **Certificaatbeheer** — self-signed certificates, trust lists, PKI infrastructuur
- **Security policies** — Basic128Rsa15, Basic256, Basic256Sha256... welke ondersteunt jouw machine?
- **Sessie management** — sessies verlopen, moeten vernieuwd worden, timeout issues
- **Browse vs. directe access** — sommige servers laten je niet browsen, je moet de NodeID al weten
- **Informatie model** — elke fabrikant implementeert het model anders, zelfs binnen dezelfde companion spec

### 3. Performance Issues

- **Polling-based** — OPC UA subscriptions zijn niet altijd betrouwbaar
- **Heavy protocol** — XML/SOAP heritage, meer overhead dan MQTT
- **Connectie limieten** — veel machines staan maar 2-5 gelijktijdige OPC UA clients toe
- **Geen multicast** — elk systeem dat data wil moet een eigen connectie openen

### 4. Fragmentatie

```
Fabrikant A: OPC UA 1.03 met custom namespace
Fabrikant B: OPC UA 1.04 met Euromap 77
Fabrikant C: OPC UA 1.05 maar alleen Basic128Rsa15 (deprecated!)
Fabrikant D: "OPC UA compatible" → alleen 5 variabelen beschikbaar
```

Elk integratieproject wordt maatwerk, ondanks de "standaard".

---

## De Workaround: Hoe kom je toch aan je data?

### Strategie 1: Gebruik wat de machine al heeft

Veel machines hebben **naast** OPC UA ook andere interfaces:

| Interface | Hoe te gebruiken |
|-----------|-----------------|
| **Modbus TCP** | Bijna alle machines hebben dit — vaak gratis en onbeperkt |
| **Focas/MTConnect** | Fanuc CNC's — gratis protocol, veel data |
| **Digitale I/O** | Simpele signalen (machine aan/uit, alarm) via PLC of IoT module |
| **Seriele poort** | RS-232/RS-485 voor oudere apparatuur |
| **Ethernet tap** | Passief netwerk verkeer mitlezen (geavanceerd) |

### Strategie 2: Externe sensoren toevoegen

Als de machine zelf geen data geeft, meet je het er omheen:

| Sensor | Meet | Protocol | Voorbeeld |
|--------|------|----------|-----------|
| **Stroomtang (CT clamp)** | Energieverbruik | Modbus, MQTT | Shelly Pro 3EM, Tasmota |
| **Trillingssensor** | Machine gezondheid | MQTT, Modbus | IFM VSA001 |
| **Temperatuursensor** | Proces temperatuur | MQTT, Modbus | PT100 via Tasmota |
| **Lichtsensor** | Machine status (stack light) | Digitaal I/O | Banner Q45 |
| **Druksensor** | Pneumatiek/hydrauliek | Modbus, 4-20mA | IFM PN7 |
| **Debietmeter** | Koelvloeistof, gas | Modbus, 4-20mA | IFM SM6 |
| **Camera** | Kwaliteitscontrole | HTTP/RTSP | Basler ace, Raspberry Pi |

> **80/20 regel:** Met een stroomtang en een stack light sensor heb je al 80% van de inzichten die je nodig hebt (machine draait/staat stil, energieverbruik, cyclustijd).

### Strategie 3: PLC als tussenpersoon

Als je een bestaande PLC hebt (Siemens, Allen-Bradley, Beckhoff):

```
Machine (geen toegang) ──→ PLC (leest I/O) ──→ UMH Core (Modbus/S7) ──→ UNS
```

- De PLC leest de digitale/analoge I/O van de machine
- UMH Core leest de PLC via Modbus of S7comm (gratis, geen licentie nodig)
- Geen OPC UA licentie nodig

### Strategie 4: MTConnect / Focas voor CNC

Veel CNC-fabrikanten ondersteunen gratis alternatieven:

| Fabrikant | Gratis protocol | Data |
|-----------|----------------|------|
| **Fanuc** | Focas2 | Spindelbelasting, assen, programma, alarmen |
| **Haas** | MDC (Machine Data Collection) | Status, cyclustijd, alarmcodes |
| **Diverse** | MTConnect | Open standaard, XML-based, veel data |

---

## Modbus — Het Werkpaard

### Waarom Modbus nog steeds relevant is

- **Gratis** — geen licenties, open protocol
- **Simpel** — adres + register, meer niet
- **Universeel** — vrijwel elk industrieel apparaat ondersteunt het
- **Betrouwbaar** — 45+ jaar bewezen in de industrie

### Modbus Basics

```
┌──────────┐         ┌──────────┐
│  Client   │ ──────→ │  Server   │
│  (UMH)    │ ←────── │ (Machine) │
└──────────┘         └──────────┘
   Vraagt              Antwoordt
   register            met waarde
```

| Concept | Uitleg |
|---------|--------|
| **Slave/Server** | Het apparaat (PLC, energiemeter, VFD) |
| **Master/Client** | De uitlezer (UMH Core) |
| **Register** | Geheugenadres op het apparaat |
| **Holding Register** | Lezen + schrijven (40001-49999) |
| **Input Register** | Alleen lezen (30001-39999) |
| **Coil** | Digitaal bit (aan/uit) |
| **Function Code** | Type operatie (03 = read holding, 04 = read input) |

### Modbus Voorbeeld: Energiemeter uitlezen

```
Apparaat: Eastron SDM630 energiemeter
Adres:    Modbus TCP, IP 192.168.1.100, Unit ID 1

Register 0x0000 (0):   Spanning fase A     → 230.5 V
Register 0x0006 (6):   Spanning fase B     → 231.2 V
Register 0x000C (12):  Spanning fase C     → 229.8 V
Register 0x0034 (52):  Totaal vermogen     → 1250.0 W
```

### Modbus in UMH Core

UMH Core heeft een ingebouwde Modbus connector:

**Bridge General tab:**
- Connection: `192.168.1.100:502`
- Protocol: Modbus TCP

**Read tab:**
- Unit ID: 1
- Registers: holding register 0, count 2 (voor 32-bit float)
- Polling interval: 5 seconden

---

## Sensortypes en hun Signalen

### Analoog vs Digitaal

| Type | Signaal | Voorbeeld | Precisie |
|------|---------|-----------|----------|
| **4-20 mA** | Stroomlus | Druk, temperatuur, niveau | Hoog |
| **0-10 V** | Spanning | Snelheid, positie | Hoog |
| **PT100/PT1000** | Weerstand | Temperatuur | Zeer hoog |
| **Thermokoppel** | mV | Hoge temperatuur (>500°C) | Hoog |
| **24V DC** | Digitaal | Aan/uit, alarm, sensor | 1 bit |
| **Encoder** | Pulsen | Positie, snelheid | Zeer hoog |

### Hoe komen analoge signalen in de UNS?

```
Sensor (4-20mA) ──→ PLC/IO-module ──→ Modbus TCP ──→ UMH Core ──→ UNS
                     ↑
              Converteert mA
              naar engineering
              waarde (bijv. bar)
```

Of met moderne IoT modules:

```
Sensor (4-20mA) ──→ IoT Gateway ──→ MQTT ──→ UMH Core ──→ UNS
                    (Tasmota, Shelly,
                     IFM IO-Link)
```

---

## UMH Core Protocol Converters

UMH Core ondersteunt deze protocollen als bridge:

| Protocol | Richting | Typisch gebruik |
|----------|----------|-----------------|
| **MQTT** | Read/Write | IoT sensoren, Tasmota, Shelly, externe brokers |
| **OPC UA** | Read | Moderne machines, CNC, robots |
| **Modbus TCP** | Read | Energiemeters, PLC's, VFD's |
| **S7comm** | Read | Siemens PLC's (S7-300/400/1200/1500) |
| **HTTP** | Read/Write | REST APIs, webhooks |

Elk protocol wordt via een bridge + tag processor omgezet naar het UNS formaat:

```
[Protocol] ──→ Bridge ──→ Tag Processor ──→ UNS (_raw)
                                              ↓
                                          Historian ──→ TimescaleDB
```

---

## Praktijk: Wanneer gebruik je wat?

### Beslisboom

```
Heeft de machine OPC UA?
├── Ja, gratis → Gebruik OPC UA bridge
├── Ja, maar duur → Bekijk alternatieven ↓
└── Nee ↓

Heeft de machine Modbus?
├── Ja → Gebruik Modbus bridge
└── Nee ↓

Heeft de machine een PLC?
├── Ja → Lees PLC via S7/Modbus
└── Nee ↓

Kun je externe sensoren plaatsen?
├── Ja → Stroomtang + stack light → MQTT
└── Nee → Overleg met machinefabrikant
```

### Kosten vergelijking

| Methode | Kosten per machine | Data kwaliteit | Implementatietijd |
|---------|--------------------|----------------|-------------------|
| OPC UA (als beschikbaar) | €0 - €25.000 | Zeer hoog | Uren - weken |
| Modbus (als beschikbaar) | €0 | Hoog | Uren |
| Externe sensoren (stroomtang) | €50 - €200 | Goed | Minuten |
| PLC uitlezen (S7/Modbus) | €0 | Hoog | Uren |
| MTConnect/Focas | €0 | Hoog | Uren - dagen |

---

## Bronnen

- [OPC Foundation](https://opcfoundation.org/) — officiele OPC UA standaard
- [Modbus Organization](https://modbus.org/) — protocol specificatie
- [UMH Protocol Converters](https://docs.umh.app/) — UMH Core bridge documentatie
- [MTConnect](https://www.mtconnect.org/) — open CNC protocol
- [IFM IO-Link](https://www.ifm.com/de/en/category/200_010_010) — industriele IoT sensoren

## Voorbereiding

1. Lees de Modbus registers van een apparaat in je netwerk (of gebruik een simulator)
2. Bekijk de OPC UA nodes van een testserver (bijv. `opc.tcp://opcuademo.sterfive.com:26543`)
3. Bedenk: welke machines in jouw fabriek hebben welk protocol?
