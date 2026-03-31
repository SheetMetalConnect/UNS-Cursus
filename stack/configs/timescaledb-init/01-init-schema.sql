-- ==============================================================================
-- Historian Schema for UMH Core
-- ==============================================================================
-- NOTE: Official UMH provides an empty TimescaleDB - no schema included.
-- This template provides a production-ready historian schema.
--
-- Tables:
--   asset      - Equipment/device metadata (with ISA-95 hierarchy columns)
--   tag        - Numeric time-series (hypertable)
--   tag_string - Text time-series (hypertable)
--
-- Executed automatically on first container startup.
-- ==============================================================================

-- Enable TimescaleDB Extension
CREATE EXTENSION IF NOT EXISTS timescaledb;

-- ==============================================================================
-- Asset Table
-- ==============================================================================
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

CREATE UNIQUE INDEX IF NOT EXISTS asset_enterprise_site_area_line_workcell_origin_id_key
  ON asset(
    COALESCE(enterprise, ''),
    COALESCE(site, ''),
    COALESCE(area, ''),
    COALESCE(line, ''),
    COALESCE(workcell, ''),
    COALESCE(origin_id, '')
  );

-- ==============================================================================
-- Tag Hypertable (Numeric Time-Series)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS tag (
    time TIMESTAMPTZ NOT NULL,
    asset_id INTEGER NOT NULL REFERENCES asset(id) ON DELETE CASCADE,
    tag_name VARCHAR(255) NOT NULL,
    value DOUBLE PRECISION,
    origin VARCHAR(255)
);

SELECT create_hypertable('tag', 'time', if_not_exists => TRUE);

-- ==============================================================================
-- Tag String Hypertable (Text Time-Series)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS tag_string (
    time TIMESTAMPTZ NOT NULL,
    asset_id INTEGER NOT NULL REFERENCES asset(id) ON DELETE CASCADE,
    tag_name VARCHAR(255) NOT NULL,
    value TEXT,
    origin VARCHAR(255)
);

SELECT create_hypertable('tag_string', 'time', if_not_exists => TRUE);

-- ==============================================================================
-- Indexes
-- ==============================================================================
CREATE INDEX IF NOT EXISTS idx_tag_asset_id ON tag (asset_id, time DESC);
CREATE INDEX IF NOT EXISTS idx_tag_asset_tag_time ON tag (asset_id, tag_name, time DESC);
CREATE INDEX IF NOT EXISTS idx_tag_tag_name_time ON tag (tag_name, time DESC);

CREATE INDEX IF NOT EXISTS idx_tag_string_asset_id ON tag_string (asset_id, time DESC);
CREATE INDEX IF NOT EXISTS idx_tag_string_asset_tag_time ON tag_string (asset_id, tag_name, time DESC);
CREATE INDEX IF NOT EXISTS idx_tag_string_tag_name_time ON tag_string (tag_name, time DESC);

-- ==============================================================================
-- Compression Policy (compress after 7 days)
-- ==============================================================================
ALTER TABLE tag SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'asset_id,tag_name',
    timescaledb.compress_orderby = 'time DESC'
);

ALTER TABLE tag_string SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'asset_id,tag_name',
    timescaledb.compress_orderby = 'time DESC'
);

SELECT add_compression_policy('tag', INTERVAL '7 days', if_not_exists => TRUE);
SELECT add_compression_policy('tag_string', INTERVAL '7 days', if_not_exists => TRUE);

-- ==============================================================================
-- get_asset_id() — UPSERT function for historian flows
-- ==============================================================================
-- Returns asset ID by ISA-95 hierarchy, auto-creates if not found.
-- Used by historian.yaml dataFlow.
CREATE OR REPLACE FUNCTION get_asset_id(
    _enterprise TEXT,
    _site TEXT DEFAULT NULL,
    _area TEXT DEFAULT NULL,
    _line TEXT DEFAULT NULL,
    _workcell TEXT DEFAULT NULL,
    _origin_id TEXT DEFAULT NULL
) RETURNS INTEGER AS $$
DECLARE
    _id INTEGER;
    _asset_name TEXT;
BEGIN
    -- Build asset_name from non-null parts
    _asset_name := COALESCE(_enterprise, '');
    IF _site IS NOT NULL THEN _asset_name := _asset_name || '.' || _site; END IF;
    IF _area IS NOT NULL THEN _asset_name := _asset_name || '.' || _area; END IF;
    IF _line IS NOT NULL THEN _asset_name := _asset_name || '.' || _line; END IF;
    IF _workcell IS NOT NULL THEN _asset_name := _asset_name || '.' || _workcell; END IF;
    IF _origin_id IS NOT NULL THEN _asset_name := _asset_name || '.' || _origin_id; END IF;

    -- Try to find existing (IS NOT DISTINCT FROM handles NULLs correctly)
    SELECT id INTO _id FROM asset
    WHERE enterprise IS NOT DISTINCT FROM _enterprise
      AND site IS NOT DISTINCT FROM _site
      AND area IS NOT DISTINCT FROM _area
      AND line IS NOT DISTINCT FROM _line
      AND workcell IS NOT DISTINCT FROM _workcell
      AND origin_id IS NOT DISTINCT FROM _origin_id;

    -- Auto-create if not found
    IF _id IS NULL THEN
        INSERT INTO asset (asset_name, enterprise, site, area, line, workcell, origin_id)
        VALUES (_asset_name, _enterprise, _site, _area, _line, _workcell, _origin_id)
        ON CONFLICT (
            COALESCE(enterprise, ''),
            COALESCE(site, ''),
            COALESCE(area, ''),
            COALESCE(line, ''),
            COALESCE(workcell, ''),
            COALESCE(origin_id, '')
        )
        DO UPDATE SET updated_at = NOW()
        RETURNING id INTO _id;
    END IF;

    RETURN _id;
END;
$$ LANGUAGE plpgsql;

-- ==============================================================================
-- Database Users for Historian
-- ==============================================================================
-- Writer user (used by UMH Core dataFlows)
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'kafkatopostgresqlv2') THEN
        CREATE ROLE kafkatopostgresqlv2 WITH LOGIN PASSWORD 'umhcore';
    END IF;
END $$;
-- Always reset password to ensure scram-sha-256 hash is correct
ALTER ROLE kafkatopostgresqlv2 WITH PASSWORD 'umhcore';

GRANT CONNECT ON DATABASE umh TO kafkatopostgresqlv2;
GRANT USAGE ON SCHEMA public TO kafkatopostgresqlv2;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO kafkatopostgresqlv2;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO kafkatopostgresqlv2;
GRANT EXECUTE ON FUNCTION get_asset_id TO kafkatopostgresqlv2;

-- Reader user (used by Grafana)
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'grafanareader') THEN
        CREATE ROLE grafanareader WITH LOGIN PASSWORD 'changeme';
    END IF;
END $$;
ALTER ROLE grafanareader WITH PASSWORD 'changeme';

GRANT CONNECT ON DATABASE umh TO grafanareader;
GRANT USAGE ON SCHEMA public TO grafanareader;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO grafanareader;
