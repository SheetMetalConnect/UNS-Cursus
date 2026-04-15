-- =================================================================
-- STAP 3: get_asset_id() functie
-- =================================================================
-- Deze functie zoekt een asset op basis van de ISA-95 hierarchy.
-- Als het asset niet bestaat, wordt het automatisch aangemaakt (UPSERT).
--
-- Gebruikt door de historian flow:
--   INSERT INTO tag (time, asset_id, tag_name, value)
--   VALUES (NOW(), get_asset_id('smc','hq','tasmota','desk','',''), 'power', 125)
--
-- Voordeel: je hoeft niet handmatig assets aan te maken.
-- Bij het eerste datapunt wordt het asset automatisch aangemaakt.
-- =================================================================

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
    -- Bouw asset_name op uit niet-null onderdelen
    _asset_name := COALESCE(_enterprise, '');
    IF _site IS NOT NULL THEN _asset_name := _asset_name || '.' || _site; END IF;
    IF _area IS NOT NULL THEN _asset_name := _asset_name || '.' || _area; END IF;
    IF _line IS NOT NULL THEN _asset_name := _asset_name || '.' || _line; END IF;
    IF _workcell IS NOT NULL THEN _asset_name := _asset_name || '.' || _workcell; END IF;
    IF _origin_id IS NOT NULL THEN _asset_name := _asset_name || '.' || _origin_id; END IF;

    -- Zoek bestaand asset (IS NOT DISTINCT FROM vergelijkt NULLs correct)
    SELECT id INTO _id FROM asset
    WHERE enterprise IS NOT DISTINCT FROM _enterprise
      AND site IS NOT DISTINCT FROM _site
      AND area IS NOT DISTINCT FROM _area
      AND line IS NOT DISTINCT FROM _line
      AND workcell IS NOT DISTINCT FROM _workcell
      AND origin_id IS NOT DISTINCT FROM _origin_id;

    -- Maak aan als het niet bestaat
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
