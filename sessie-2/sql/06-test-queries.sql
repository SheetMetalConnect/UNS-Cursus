-- =================================================================
-- STAP 6: Test queries
-- =================================================================
-- Gebruik deze queries om te controleren of alles werkt.
-- Handig voor DBeaver, Grafana Explore, of psql.
-- =================================================================

-- Alle assets bekijken
SELECT id, asset_name, enterprise, site, area, line
FROM asset
ORDER BY enterprise, site, area, line;

-- Test get_asset_id() — zoekt op, of maakt automatisch aan
SELECT get_asset_id('smc', 'hq', 'tasmota', 'desk', '', '') AS desk_id;

-- Hypertable info — hoeveel chunks, compressie aan?
SELECT hypertable_name, num_chunks, compression_enabled
FROM timescaledb_information.hypertables
WHERE hypertable_name IN ('tag', 'tag_string');

-- Compressie beleid
SELECT hypertable_name, schedule_interval
FROM timescaledb_information.jobs
WHERE proc_name = 'policy_compression';

-- Handmatig een datapunt invoegen (test)
INSERT INTO tag (time, asset_id, tag_name, value, origin)
VALUES (NOW(), get_asset_id('smc', 'hq', 'tasmota', 'desk', '', ''), 'power', 125.5, 'manual_test');

-- Controleer of het erin staat
SELECT t.time, a.asset_name, t.tag_name, t.value, t.origin
FROM tag t
JOIN asset a ON a.id = t.asset_id
ORDER BY t.time DESC
LIMIT 10;

-- Alle data van 1 asset (laatste uur)
SELECT t.time, t.tag_name, t.value
FROM tag t
JOIN asset a ON a.id = t.asset_id
WHERE a.asset_name = 'smc.hq.tasmota.desk'
  AND t.time > NOW() - INTERVAL '1 hour'
ORDER BY t.time DESC;

-- Alle data per enterprise (hierarchisch filteren)
SELECT a.enterprise, a.site, a.area, a.line, count(*) AS datapunten
FROM tag t
JOIN asset a ON a.id = t.asset_id
WHERE t.time > NOW() - INTERVAL '1 hour'
GROUP BY a.enterprise, a.site, a.area, a.line
ORDER BY a.enterprise, a.site, a.area, a.line;

-- TimescaleDB time_bucket — gemiddelde per minuut
SELECT
  time_bucket('1 minute', t.time) AS minuut,
  a.asset_name,
  t.tag_name,
  avg(t.value) AS gem_waarde,
  count(*) AS metingen
FROM tag t
JOIN asset a ON a.id = t.asset_id
WHERE t.time > NOW() - INTERVAL '30 minutes'
GROUP BY 1, 2, 3
ORDER BY 1 DESC, 2, 3;
