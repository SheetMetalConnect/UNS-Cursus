-- ==============================================================================
-- Fix voor bestaande database
-- ==============================================================================
-- Draai dit ALLEEN als je stack al eerder gestart is.
--
-- Dit script:
--   1. Maakt hierarchy kolommen nullable (verwijdert NOT NULL)
--   2. Converteert lege strings naar NULL
--   3. Vervangt de unique index met een COALESCE-versie
--   4. Updatet get_asset_id() voor NULL-safe vergelijkingen
--
-- Optie 1 (aanbevolen): fresh start
--   docker compose down -v
--   docker compose up -d
--
-- Optie 2: draai dit script in DBeaver (localhost:5432, postgres/changeme, database: umh)
-- ==============================================================================

-- Stap 1: Verwijder NOT NULL constraints
ALTER TABLE asset ALTER COLUMN enterprise DROP NOT NULL;
ALTER TABLE asset ALTER COLUMN enterprise DROP DEFAULT;
ALTER TABLE asset ALTER COLUMN site DROP NOT NULL;
ALTER TABLE asset ALTER COLUMN site DROP DEFAULT;
ALTER TABLE asset ALTER COLUMN area DROP NOT NULL;
ALTER TABLE asset ALTER COLUMN area DROP DEFAULT;
ALTER TABLE asset ALTER COLUMN line DROP NOT NULL;
ALTER TABLE asset ALTER COLUMN line DROP DEFAULT;
ALTER TABLE asset ALTER COLUMN workcell DROP NOT NULL;
ALTER TABLE asset ALTER COLUMN workcell DROP DEFAULT;
ALTER TABLE asset ALTER COLUMN origin_id DROP NOT NULL;
ALTER TABLE asset ALTER COLUMN origin_id DROP DEFAULT;

-- Stap 2: Lege strings → NULL
UPDATE asset SET enterprise = NULLIF(enterprise, '');
UPDATE asset SET site = NULLIF(site, '');
UPDATE asset SET area = NULLIF(area, '');
UPDATE asset SET line = NULLIF(line, '');
UPDATE asset SET workcell = NULLIF(workcell, '');
UPDATE asset SET origin_id = NULLIF(origin_id, '');

-- Stap 3: Vervang unique index met COALESCE-versie
DROP INDEX IF EXISTS asset_hierarchy_key;
DROP INDEX IF EXISTS asset_enterprise_site_area_line_workcell_origin_id_key;
CREATE UNIQUE INDEX asset_hierarchy_key
  ON asset(
    COALESCE(enterprise, ''),
    COALESCE(site, ''),
    COALESCE(area, ''),
    COALESCE(line, ''),
    COALESCE(workcell, ''),
    COALESCE(origin_id, '')
  );

-- Stap 4: Update functie
CREATE OR REPLACE FUNCTION get_asset_id(
    _enterprise TEXT,
    _site TEXT DEFAULT NULL,
    _area TEXT DEFAULT NULL,
    _line TEXT DEFAULT NULL,
    _workcell TEXT DEFAULT NULL,
    _origin_id TEXT DEFAULT NULL
) RETURNS INTEGER AS $func$
DECLARE
    _id INTEGER;
    _asset_name TEXT;
BEGIN
    _asset_name := COALESCE(_enterprise, '');
    IF _site IS NOT NULL THEN _asset_name := _asset_name || '.' || _site; END IF;
    IF _area IS NOT NULL THEN _asset_name := _asset_name || '.' || _area; END IF;
    IF _line IS NOT NULL THEN _asset_name := _asset_name || '.' || _line; END IF;
    IF _workcell IS NOT NULL THEN _asset_name := _asset_name || '.' || _workcell; END IF;
    IF _origin_id IS NOT NULL THEN _asset_name := _asset_name || '.' || _origin_id; END IF;

    SELECT id INTO _id FROM asset
    WHERE enterprise IS NOT DISTINCT FROM _enterprise
      AND site IS NOT DISTINCT FROM _site
      AND area IS NOT DISTINCT FROM _area
      AND line IS NOT DISTINCT FROM _line
      AND workcell IS NOT DISTINCT FROM _workcell
      AND origin_id IS NOT DISTINCT FROM _origin_id;

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
$func$ LANGUAGE plpgsql;
