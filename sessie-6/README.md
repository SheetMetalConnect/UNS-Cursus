# Sessie 6 — AI-integratie & Data naar de Cloud

## Bestanden

### BigQuery ML

| Bestand | Wat het doet |
|---------|-------------|
| `bigquery/01-create-tables.sql` | BigQuery tabellen aanmaken |
| `bigquery/02-solar-forecast.sql` | Solar vermogen voorspellen (ARIMA_PLUS) |
| `bigquery/03-anomaly-detection.sql` | Anomaly detection op machine data |
| `bigquery/04-weather-regression.sql` | Weer → solar output regressie |

### Data exports (CSV → BigQuery upload)

| Bestand | Rijen | Inhoud |
|---------|-------|--------|
| `bigquery/solar_pivoted_1min.csv` | ~4.400 | Solar power per minuut |
| `bigquery/weather_pivoted_5min.csv` | ~900 | Weer per 5 minuten |
| `bigquery/machine_pivoted_1min.csv` | ~4.000 | Machine runtime per minuut |

## BigQuery setup

1. Maak een GCP project aan (gratis tier)
2. BigQuery Console → dataset `uns_cursus` aanmaken
3. `01-create-tables.sql` uitvoeren
4. CSV's uploaden naar de tabellen
5. Demo queries uitvoeren (02, 03, 04)

## Drie demo's

| # | Use case | Model | Data |
|---|----------|-------|------|
| 1 | Hoeveel stroom leveren mijn panelen morgen? | ARIMA_PLUS forecast | Solar power |
| 2 | Draait mijn machine normaal? | Anomaly detection | Machine runtimes |
| 3 | Welk weer bepaalt mijn opbrengst? | Linear regression | Weer + solar |
