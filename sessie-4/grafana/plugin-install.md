# Grafana Plugin Installeren — Referentie

Grafana plugins breiden de standaard functionaliteit uit. Drie types:

| Type | Voorbeeld |
|------|-----------|
| **Panel** | Nieuwe visualisatie (bv. Business Forms) |
| **Data source** | Nieuwe database-backend |
| **App** | Volledige UI-module |

## Installatie via docker-compose.yaml

Eén environment variable toevoegen aan de `grafana` service:

```yaml
grafana:
  environment:
    - GF_INSTALL_PLUGINS=volkovlabs-form-panel
```

Meerdere plugins tegelijk:

```yaml
    - GF_INSTALL_PLUGINS=plugin-id-1,plugin-id-2,plugin-id-3
```

Toepassen:

```bash
cd stack
docker compose up -d grafana
docker compose logs grafana -f   # wacht tot plugin gedownload is
```

Verifiëren: **Administration → Plugins & data → Plugins** → plugin staat op "Installed".

## Belangrijk

- Volume `grafana-data` bewaart plugins + dashboards bij `down`/`up`
- `docker compose down -v` wist alles (plugins, dashboards, data source config)
- Verkeerd plugin-ID → install faalt stil. Altijd logs checken.
- Plugin ID vind je op [grafana.com/grafana/plugins](https://grafana.com/grafana/plugins/)
