# Sessie 2 — Docker, TimescaleDB & Grafana

## Stack starten

```bash
cd stack
cp .env.example .env   # vul AUTH_TOKEN in
docker compose up -d
```

## Historian deployen

Management Console → Stand-alone → Add → plak `../sessie-3/flows/historian.yaml`

## Referentie

- `sql/` — Database schema scripts
- `grafana/` — Grafana setup en query voorbeelden
