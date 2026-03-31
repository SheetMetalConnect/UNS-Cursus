-- =================================================================
-- Grafana Queries — Sessie 2
-- =================================================================
-- Gebruik deze queries in Grafana → Explore of in een Dashboard panel.
--
-- Datasource: UMH TimescaleDB (al geconfigureerd via provisioning)
--   Host: timescaledb:5432
--   Database: umh
--   User: grafanareader
--   Password: changeme
--
-- Als je handmatig een datasource toevoegt in Grafana:
--   1. Ga naar Connections → Data sources → Add data source
--   2. Kies "PostgreSQL"
--   3. Host: timescaledb:5432 (of localhost:5432 als je buiten Docker werkt)
--   4. Database: umh
--   5. User: grafanareader / Password: changeme
--   6. TLS/SSL Mode: disable
--   7. Zet "TimescaleDB" aan onder PostgreSQL details
--   8. Save & Test
-- =================================================================


-- =================================================================
-- QUERY 1: Alle assets met hun databronnen
-- =================================================================
-- Gebruik: Table panel
-- Laat zien welke assets er zijn en hoeveel data ze hebben
SELECT
  a.enterprise AS "Enterprise",
  a.site AS "Site",
  a.area AS "Afdeling",
  a.line AS "Machine",
  count(DISTINCT t.tag_name) AS "Unieke Tags",
  count(*) AS "Datapunten",
  max(t.time) AS "Laatste Data"
FROM asset a
LEFT JOIN tag t ON t.asset_id = a.id AND t.time > NOW() - INTERVAL '1 hour'
GROUP BY a.enterprise, a.site, a.area, a.line
ORDER BY a.enterprise, a.site, a.area, a.line;


-- =================================================================
-- QUERY 2: Laser vermogen over tijd
-- =================================================================
-- Gebruik: Time series panel
-- Format: Time series
SELECT
  time_bucket('30 seconds', t.time) AS time,
  avg(t.value) AS "Laser Power (W)"
FROM tag t
JOIN asset a ON a.id = t.asset_id
WHERE a.asset_name = 'metalfab.eindhoven.cutting.laser_01'
  AND t.tag_name = 'laser_power'
  AND $__timeFilter(t.time)
GROUP BY 1
ORDER BY 1;


-- =================================================================
-- QUERY 3: Kantbank tonnage over tijd
-- =================================================================
-- Gebruik: Time series panel
SELECT
  time_bucket('30 seconds', t.time) AS time,
  avg(t.value) AS "Tonnage (kN)"
FROM tag t
JOIN asset a ON a.id = t.asset_id
WHERE a.asset_name = 'metalfab.eindhoven.forming.press_brake_01'
  AND t.tag_name = 'tonnage'
  AND $__timeFilter(t.time)
GROUP BY 1
ORDER BY 1;


-- =================================================================
-- QUERY 4: Tasmota energieverbruik alle devices
-- =================================================================
-- Gebruik: Time series panel
-- Meerdere lijnen — 1 per device
SELECT
  time_bucket('1 minute', t.time) AS time,
  a.line AS metric,
  avg(t.value) AS "Power (W)"
FROM tag t
JOIN asset a ON a.id = t.asset_id
WHERE a.enterprise = 'smc'
  AND t.tag_name = 'power'
  AND $__timeFilter(t.time)
GROUP BY 1, 2
ORDER BY 1;


-- =================================================================
-- QUERY 5: Temperatuur alle Tasmota devices
-- =================================================================
-- Gebruik: Time series panel
SELECT
  time_bucket('1 minute', t.time) AS time,
  a.line AS metric,
  avg(t.value) AS "Temperature (C)"
FROM tag t
JOIN asset a ON a.id = t.asset_id
WHERE a.enterprise = 'smc'
  AND t.tag_name = 'temperature'
  AND $__timeFilter(t.time)
GROUP BY 1, 2
ORDER BY 1;


-- =================================================================
-- QUERY 6: Machine states (tekst uit tag_string)
-- =================================================================
-- Gebruik: Table panel
-- Laat zien hoe tekst-data in tag_string terechtkomt
SELECT
  t.time AS "Tijd",
  a.asset_name AS "Machine",
  t.tag_name AS "Tag",
  t.value AS "Status"
FROM tag_string t
JOIN asset a ON a.id = t.asset_id
WHERE $__timeFilter(t.time)
ORDER BY t.time DESC
LIMIT 50;


-- =================================================================
-- QUERY 7: OEE overzicht per machine
-- =================================================================
-- Gebruik: Gauge of Stat panel
SELECT
  a.asset_name AS metric,
  t.tag_name,
  round(avg(t.value)::numeric * 100, 1) AS "percentage"
FROM tag t
JOIN asset a ON a.id = t.asset_id
WHERE a.enterprise = 'metalfab'
  AND t.tag_name LIKE 'oee.%'
  AND $__timeFilter(t.time)
GROUP BY a.asset_name, t.tag_name
ORDER BY a.asset_name, t.tag_name;


-- =================================================================
-- QUERY 8: Alle data van 1 asset (voor variabele $asset)
-- =================================================================
-- Gebruik: Time series panel met Grafana variable
-- Maak een variable aan: Query type = "Query", Query = SELECT DISTINCT asset_name FROM asset
SELECT
  time_bucket('30 seconds', t.time) AS time,
  t.tag_name AS metric,
  avg(t.value) AS value
FROM tag t
JOIN asset a ON a.id = t.asset_id
WHERE a.asset_name = '$asset'
  AND $__timeFilter(t.time)
GROUP BY 1, 2
ORDER BY 1;
