-- ==============================================================================
-- Fix voor bestaande database
-- ==============================================================================
-- Draai dit ALLEEN als je stack al eerder gestart is en je deze error krijgt:
--   "null value in column workcell of relation asset violates not-null constraint"
--
-- Optie 1 (aanbevolen): fresh start
--   docker compose down -v
--   docker compose up -d
--
-- Optie 2: draai dit script in DBeaver (localhost:5432, postgres/changeme, database: umh)
-- ==============================================================================

CREATE OR REPLACE FUNCTION get_asset_id(
    _enterprise TEXT,
    _site TEXT DEFAULT '',
    _area TEXT DEFAULT '',
    _line TEXT DEFAULT '',
    _workcell TEXT DEFAULT '',
    _origin_id TEXT DEFAULT ''
) RETURNS INTEGER AS $func$
DECLARE
    _id INTEGER;
    _asset_name TEXT;
BEGIN
    _enterprise := COALESCE(_enterprise, '');
    _site := COALESCE(_site, '');
    _area := COALESCE(_area, '');
    _line := COALESCE(_line, '');
    _workcell := COALESCE(_workcell, '');
    _origin_id := COALESCE(_origin_id, '');

    _asset_name := _enterprise;
    IF _site <> '' THEN _asset_name := _asset_name || '.' || _site; END IF;
    IF _area <> '' THEN _asset_name := _asset_name || '.' || _area; END IF;
    IF _line <> '' THEN _asset_name := _asset_name || '.' || _line; END IF;
    IF _workcell <> '' THEN _asset_name := _asset_name || '.' || _workcell; END IF;
    IF _origin_id <> '' THEN _asset_name := _asset_name || '.' || _origin_id; END IF;

    SELECT id INTO _id FROM asset
    WHERE enterprise = _enterprise AND site = _site AND area = _area
      AND line = _line AND workcell = _workcell AND origin_id = _origin_id;

    IF _id IS NULL THEN
        INSERT INTO asset (asset_name, enterprise, site, area, line, workcell, origin_id)
        VALUES (_asset_name, _enterprise, _site, _area, _line, _workcell, _origin_id)
        ON CONFLICT (enterprise, site, area, line, workcell, origin_id)
        DO UPDATE SET updated_at = NOW()
        RETURNING id INTO _id;
    END IF;

    RETURN _id;
END;
$func$ LANGUAGE plpgsql;
