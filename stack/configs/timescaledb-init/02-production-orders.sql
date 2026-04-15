-- ==============================================================================
-- Sessie 4 — Production Orders Schema
-- ==============================================================================
-- Werkorder tabel voor ERP-integratie via UMH Core API
-- Gebruikt door: erp-order-bridge standalone flow
--
-- Handmatig draaien als de database al bestaat:
--   Open DBeaver → verbind met localhost:5432/umh (postgres/changeme)
--   Voer dit script uit
-- ==============================================================================

CREATE TABLE IF NOT EXISTS production_orders (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT now(),
    asset_id INTEGER REFERENCES asset(id),
    order_id VARCHAR(255) NOT NULL UNIQUE,
    customer VARCHAR(255),
    part_number VARCHAR(255),
    part_description TEXT,
    quantity INTEGER NOT NULL DEFAULT 0,
    quantity_completed INTEGER NOT NULL DEFAULT 0,
    quantity_scrap INTEGER NOT NULL DEFAULT 0,
    priority INTEGER,
    status VARCHAR(50) NOT NULL DEFAULT 'CREATED',
    due_date TIMESTAMPTZ,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    planned_cycle_time_ms NUMERIC,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_production_orders_asset ON production_orders (asset_id);
CREATE INDEX IF NOT EXISTS idx_production_orders_status ON production_orders (status);
CREATE INDEX IF NOT EXISTS idx_production_orders_started ON production_orders (started_at DESC);

-- Rechten voor writer en reader gebruikers
GRANT SELECT, INSERT, UPDATE, DELETE ON production_orders TO kafkatopostgresqlv2;
GRANT USAGE, SELECT ON SEQUENCE production_orders_id_seq TO kafkatopostgresqlv2;
GRANT SELECT ON production_orders TO grafanareader;
