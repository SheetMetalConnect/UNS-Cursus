-- ==============================================================================
-- Sessie 5, Deel 2 — Work Orders Schema (met history tracking)
-- ==============================================================================
-- Voer dit script uit in DBeaver (localhost:5432/umh, postgres/changeme)
--
-- Maakt aan:
--   1. get_asset_id()             — zet ISA-95 locatie om naar een asset ID
--   2. erp_work_order             — huidige staat van elke werkorder (upsert)
--   3. erp_work_order_history     — audit trail van alle wijzigingen
--   4. updated_at trigger         — automatische timestamp bij wijziging
--
-- Dit is de uitgebreide variant met deduplicatie en history tracking.
-- ==============================================================================

-- =============
-- Helper: updated_at trigger
-- =============

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- =============
-- Asset ID Lookup — defined in 01-init-schema.sql (TEXT signature)
-- Do NOT redefine here to avoid dual-signature conflicts
-- =============
-- Work Order — huidige staat
-- =============

CREATE TABLE IF NOT EXISTS erp_work_order (
    order_nr TEXT NOT NULL,
    asset_id INTEGER NOT NULL REFERENCES asset(id) ON DELETE CASCADE,
    product TEXT,
    qty INTEGER DEFAULT 0,
    customer TEXT,
    priority INTEGER,
    due_date TIMESTAMPTZ,
    status TEXT,
    change_type TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (order_nr, asset_id)
);

DROP TRIGGER IF EXISTS tr_erp_work_order_updated ON erp_work_order;
CREATE TRIGGER tr_erp_work_order_updated BEFORE UPDATE ON erp_work_order
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE INDEX IF NOT EXISTS idx_erp_work_order_status ON erp_work_order (status);
CREATE INDEX IF NOT EXISTS idx_erp_work_order_due ON erp_work_order (due_date);

-- =============
-- Work Order History — audit trail (append-only)
-- =============

CREATE TABLE IF NOT EXISTS erp_work_order_history (
    history_id BIGSERIAL PRIMARY KEY,
    order_nr TEXT NOT NULL,
    asset_id INTEGER NOT NULL,
    product TEXT,
    qty INTEGER DEFAULT 0,
    customer TEXT,
    priority INTEGER,
    due_date TIMESTAMPTZ,
    status TEXT,
    change_type TEXT NOT NULL,
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_erp_work_order_history_recorded
    ON erp_work_order_history (recorded_at DESC);

-- Rechten
GRANT SELECT, INSERT, UPDATE, DELETE ON erp_work_order TO kafkatopostgresqlv2;
GRANT SELECT, INSERT ON erp_work_order_history TO kafkatopostgresqlv2;
GRANT USAGE, SELECT ON SEQUENCE erp_work_order_history_history_id_seq TO kafkatopostgresqlv2;
GRANT SELECT ON erp_work_order TO grafanareader;
GRANT SELECT ON erp_work_order_history TO grafanareader;
