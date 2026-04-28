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
-- Asset ID Lookup
-- =============

CREATE OR REPLACE FUNCTION get_asset_id(
    p_enterprise VARCHAR,
    p_site VARCHAR,
    p_area VARCHAR,
    p_line VARCHAR,
    p_workcell VARCHAR,
    p_origin_id VARCHAR
) RETURNS INTEGER AS $$
DECLARE
    v_asset_id INTEGER;
    v_asset_name VARCHAR;
    v_location VARCHAR;
    v_parts TEXT[];
BEGIN
    v_parts := ARRAY[]::TEXT[];
    IF p_enterprise IS NOT NULL AND p_enterprise != '' THEN
        v_parts := array_append(v_parts, p_enterprise);
    END IF;
    IF p_site IS NOT NULL AND p_site != '' THEN
        v_parts := array_append(v_parts, p_site);
    END IF;
    IF p_area IS NOT NULL AND p_area != '' THEN
        v_parts := array_append(v_parts, p_area);
    END IF;
    IF p_line IS NOT NULL AND p_line != '' THEN
        v_parts := array_append(v_parts, p_line);
    END IF;
    IF p_workcell IS NOT NULL AND p_workcell != '' THEN
        v_parts := array_append(v_parts, p_workcell);
    END IF;
    IF p_origin_id IS NOT NULL AND p_origin_id != '' THEN
        v_parts := array_append(v_parts, p_origin_id);
    END IF;

    IF array_length(v_parts, 1) IS NULL OR array_length(v_parts, 1) = 0 THEN
        RETURN NULL;
    ELSIF array_length(v_parts, 1) = 1 THEN
        v_asset_name := v_parts[1];
        v_location := '';
    ELSE
        v_asset_name := v_parts[array_length(v_parts, 1)];
        v_location := array_to_string(v_parts[1:array_length(v_parts, 1)-1], '.');
    END IF;

    INSERT INTO asset (
        asset_name, location,
        enterprise, site, area, line, workcell, origin_id
    )
    VALUES (
        v_asset_name, v_location,
        COALESCE(p_enterprise, ''),
        COALESCE(p_site, ''),
        COALESCE(p_area, ''),
        COALESCE(p_line, ''),
        COALESCE(p_workcell, ''),
        COALESCE(p_origin_id, '')
    )
    ON CONFLICT (asset_name) DO UPDATE SET
        location = EXCLUDED.location,
        updated_at = NOW()
    RETURNING id INTO v_asset_id;

    RETURN v_asset_id;
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION get_asset_id(VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR) TO kafkatopostgresqlv2;

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
