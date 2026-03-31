-- =================================================================
-- STAP 1: Schema aanmaken
-- =================================================================
-- Open DBeaver → verbind met TimescaleDB (localhost:5432, user: postgres, pw: changeme, db: umh)
-- Open SQL Editor → plak dit script → Execute (Ctrl+Enter)
--
-- Dit maakt de basis tabellen aan voor de historian.
-- =================================================================

-- TimescaleDB extensie activeren
CREATE EXTENSION IF NOT EXISTS timescaledb;

-- =================================================================
-- Asset tabel — ISA-95 equipment hierarchy
-- =================================================================
-- Elke machine/sensor/device krijgt een rij in deze tabel.
-- De kolommen volgen de ISA-95 standaard:
--   enterprise → site → area → line → workcell → origin_id
--
-- Voorbeeld:
--   enterprise=smc, site=hq, area=tasmota, line=desk
--   enterprise=metalfab, site=eindhoven, area=cutting, line=laser_01

CREATE TABLE IF NOT EXISTS asset (
    id SERIAL PRIMARY KEY,
    asset_name VARCHAR(255) NOT NULL UNIQUE,
    location VARCHAR(500),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    enterprise TEXT,
    site TEXT,
    area TEXT,
    line TEXT,
    workcell TEXT,
    origin_id TEXT
);

CREATE UNIQUE INDEX IF NOT EXISTS asset_hierarchy_key
  ON asset(
    COALESCE(enterprise, ''),
    COALESCE(site, ''),
    COALESCE(area, ''),
    COALESCE(line, ''),
    COALESCE(workcell, ''),
    COALESCE(origin_id, '')
  );
