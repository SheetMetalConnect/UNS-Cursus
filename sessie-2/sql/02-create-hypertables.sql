-- =================================================================
-- STAP 2: Hypertables aanmaken (TimescaleDB feature)
-- =================================================================
-- Dit zijn gewone PostgreSQL tabellen, maar TimescaleDB partitioneert
-- ze automatisch op tijd. Dat geeft:
--   - Snelle INSERTs (schrijft alleen naar nieuwste chunk)
--   - Snelle queries (scant alleen relevante tijdperiode)
--   - Automatische compressie (90%+ kleiner na 7 dagen)
-- =================================================================

-- Tag tabel — numerieke tijdreeksdata (temperatuur, vermogen, spanning, etc.)
CREATE TABLE IF NOT EXISTS tag (
    time TIMESTAMPTZ NOT NULL,
    asset_id INTEGER NOT NULL REFERENCES asset(id) ON DELETE CASCADE,
    tag_name VARCHAR(255) NOT NULL,
    value DOUBLE PRECISION,
    origin VARCHAR(255)
);

-- Maak er een hypertable van (partitioneert automatisch op 'time')
SELECT create_hypertable('tag', 'time', if_not_exists => TRUE);

-- Tag string tabel — tekst tijdreeksdata (status namen, foutmeldingen, etc.)
CREATE TABLE IF NOT EXISTS tag_string (
    time TIMESTAMPTZ NOT NULL,
    asset_id INTEGER NOT NULL REFERENCES asset(id) ON DELETE CASCADE,
    tag_name VARCHAR(255) NOT NULL,
    value TEXT,
    origin VARCHAR(255)
);

SELECT create_hypertable('tag_string', 'time', if_not_exists => TRUE);

-- =================================================================
-- Indexes voor snelle queries
-- =================================================================
CREATE INDEX IF NOT EXISTS idx_tag_asset_time ON tag (asset_id, time DESC);
CREATE INDEX IF NOT EXISTS idx_tag_asset_tag_time ON tag (asset_id, tag_name, time DESC);
CREATE INDEX IF NOT EXISTS idx_tag_tagname_time ON tag (tag_name, time DESC);

CREATE INDEX IF NOT EXISTS idx_tag_string_asset_time ON tag_string (asset_id, time DESC);
CREATE INDEX IF NOT EXISTS idx_tag_string_asset_tag_time ON tag_string (asset_id, tag_name, time DESC);
CREATE INDEX IF NOT EXISTS idx_tag_string_tagname_time ON tag_string (tag_name, time DESC);

-- =================================================================
-- Compressie beleid — oude data automatisch comprimeren na 7 dagen
-- =================================================================
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
