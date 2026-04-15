-- =============================================================================
-- Sessie 4 — Grafana Query Voorbeelden
-- =============================================================================
-- Gebruik in Grafana: New Panel → Data source: UMH TimescaleDB → Code mode
-- =============================================================================

-- ---------------------------------------------------------------------------
-- NIVEAU 1 — Stat panel: één getal
-- ---------------------------------------------------------------------------

-- Aantal assets in de database
SELECT count(*) FROM asset;

-- Aantal meetwaarden afgelopen uur
SELECT count(*)
FROM tag
WHERE time > now() - interval '1 hour';


-- ---------------------------------------------------------------------------
-- NIVEAU 2 — Time series: één lijn
-- ---------------------------------------------------------------------------

-- Gemiddeld laservermogen per 30 seconden
SELECT time_bucket('30 seconds', t.time) AS time,
       avg(t.value) AS "Laser Power (W)"
FROM tag t
JOIN asset a ON a.id = t.asset_id
WHERE a.enterprise = 'metalfab'
  AND a.line = 'laser_01'
  AND t.tag_name = 'laser_power_w'
  AND $__timeFilter(t.time)
GROUP BY 1
ORDER BY 1;


-- ---------------------------------------------------------------------------
-- NIVEAU 3 — Time series: meerdere lijnen per machine
-- ---------------------------------------------------------------------------

-- Laservermogen per productielijn
SELECT time_bucket('1 minute', t.time) AS time,
       a.line AS metric,
       avg(t.value) AS "Laser Power (W)"
FROM tag t
JOIN asset a ON a.id = t.asset_id
WHERE a.enterprise = 'metalfab'
  AND t.tag_name = 'laser_power_w'
  AND $__timeFilter(t.time)
GROUP BY 1, 2
ORDER BY 1;


-- ---------------------------------------------------------------------------
-- NIVEAU 4 — Werkorders (production_orders tabel)
-- ---------------------------------------------------------------------------

-- Alle werkorders met machine, klant en prioriteit
SELECT po.order_id AS "Order",
       a.line AS "Machine",
       po.part_number AS "Product",
       po.customer AS "Klant",
       po.priority AS "Prioriteit",
       po.quantity AS "Gepland",
       po.quantity_completed AS "Gereed",
       po.quantity_scrap AS "Uitval",
       po.status AS "Status",
       po.created_at AS "Aangemaakt"
FROM production_orders po
JOIN asset a ON a.id = po.asset_id
ORDER BY po.created_at DESC;

-- Actieve werkorders
SELECT po.order_id AS "Order",
       a.line AS "Machine",
       po.customer AS "Klant",
       po.priority AS "Prioriteit",
       po.quantity AS "Gepland",
       po.status AS "Status"
FROM production_orders po
JOIN asset a ON a.id = po.asset_id
WHERE po.status IN ('CREATED', 'IN_PROGRESS')
ORDER BY po.priority ASC, po.created_at DESC;

-- Werkorder status verdeling (voor pie chart)
SELECT status, count(*) AS aantal
FROM production_orders
GROUP BY status;

-- Productie per lijn (bar chart)
SELECT a.line AS "Productielijn",
       sum(po.quantity) AS "Gepland",
       sum(po.quantity_completed) AS "Geproduceerd",
       sum(po.quantity_scrap) AS "Uitval"
FROM production_orders po
JOIN asset a ON a.id = po.asset_id
GROUP BY a.line
ORDER BY "Gepland" DESC;

-- Totaal gepland vs gereed (stat panels)
SELECT sum(quantity) AS "Totaal gepland" FROM production_orders;
SELECT sum(quantity_completed) AS "Totaal gereed" FROM production_orders;
SELECT count(*) AS "Aantal orders" FROM production_orders;
