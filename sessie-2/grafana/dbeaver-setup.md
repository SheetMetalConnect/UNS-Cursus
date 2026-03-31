# DBeaver — Database verbinden

## Waarom DBeaver?

- Gratis, cross-platform (Windows/Mac/Linux)
- Visueel SQL editor met autocomplete
- Tabel structuur direct zichtbaar
- Query resultaten als tabel, niet alleen terminal output
- Ideaal om TimescaleDB te verkennen voordat je Grafana queries schrijft

## Verbinding aanmaken

1. Open DBeaver
2. Klik **New Database Connection** (stekker icoon linksboven)
3. Kies **PostgreSQL** → Next
4. Vul in:
   - Host: `localhost`
   - Port: `5432`
   - Database: `umh`
   - Username: `postgres`
   - Password: `changeme`
5. Klik **Test Connection** → "Connected"
6. Klik **Finish**

## Waarom `postgres` user in DBeaver?

- In DBeaver gebruik je `postgres` (superuser) — je wilt alles kunnen zien en wijzigen
- In Grafana gebruik je `grafanareader` (read-only) — veiligheid, kan geen data wijzigen
- In UMH Core gebruikt de historian `kafkatopostgresqlv2` (schrijver) — kan INSERT/UPDATE

Drie gebruikers, drie rollen, elk met de juiste rechten.

## Na het verbinden

Links in de navigator zie je:
```
umh (database)
└── Schemas
    └── public
        ├── Tables
        │   ├── asset          ← ISA-95 equipment hierarchy
        │   ├── tag            ← numerieke tijdreeksdata (hypertable)
        │   └── tag_string     ← tekst tijdreeksdata (hypertable)
        └── Functions
            └── get_asset_id   ← auto-create assets
```

Dubbelklik op een tabel om de structuur te zien.
Rechtermuisklik → View Data om de inhoud te bekijken.

## SQL uitvoeren

1. Klik **SQL Editor** → **New SQL Script** (of Ctrl+])
2. Plak een query uit `sessie2/sql/06-test-queries.sql`
3. Selecteer de query → Ctrl+Enter om uit te voeren
4. Resultaat verschijnt onderaan

## Tip: meerdere queries

Je kunt meerdere queries in 1 script zetten.
Selecteer er 1 en druk Ctrl+Enter — alleen die query wordt uitgevoerd.
