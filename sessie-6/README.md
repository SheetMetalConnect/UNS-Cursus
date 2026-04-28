# Sessie 6 — AI-integratie & Data naar de Cloud

In de vorige sessies hebben we data van de werkvloer naar de UNS gebracht en dashboards gebouwd. Nu gaan we een stap verder: data uit de UNS naar externe systemen sturen voor analyse en machine learning.

## Leerdoelen

- Data uit TimescaleDB exporteren naar een cloud data warehouse (BigQuery)
- Een connector opzetten tussen de UNS en externe ML/analytics services
- Begrijpen wanneer je data lokaal houdt vs. naar de cloud stuurt
- Een eenvoudige voorspelling of classificatie draaien op je fabrieksdata

## Wat we bouwen

```
TimescaleDB ──→ BigQuery Connector ──→ BigQuery / Cloud DWH
                                           │
UNS (Redpanda) ──→ ML Service ──→ Predictions terug naar UNS
```

## Onderwerpen

### Part 1 — Data naar de Cloud
- BigQuery (of alternatief) als cloud data warehouse
- Connector configureren: welke data, hoe vaak, welk formaat
- Privacy en security: wat stuur je wel/niet naar de cloud

### Part 2 — AI/ML op fabrieksdata
- Voorbeelden: voorspellend onderhoud, kwaliteitscontrole, anomaly detection
- Een ML-model aanroepen vanuit de UNS pipeline
- Resultaten terugsturen naar de namespace

## Voorbereiding

Materiaal volgt. Zorg dat je stack uit sessie 5 nog draait.

## Bestanden

```
sessie-6/
  README.md              <- deze handleiding
```
