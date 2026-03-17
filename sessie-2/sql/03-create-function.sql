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
    _site TEXT DEFAULT '',
    _area TEXT DEFAULT '',
    _line TEXT DEFAULT '',
    _workcell TEXT DEFAULT '',
    _origin_id TEXT DEFAULT ''
) RETURNS INTEGER AS $$
DECLARE
    _id INTEGER;
    _asset_name TEXT;
BEGIN
    -- NULL naar lege string (Benthos stuurt soms null i.p.v. '')
    _enterprise := COALESCE(_enterprise, '');
    _site := COALESCE(_site, '');
    _area := COALESCE(_area, '');
    _line := COALESCE(_line, '');
    _workcell := COALESCE(_workcell, '');
    _origin_id := COALESCE(_origin_id, '');

    -- Bouw asset_name op uit niet-lege onderdelen
    _asset_name := _enterprise;
    IF _site <> '' THEN _asset_name := _asset_name || '.' || _site; END IF;
    IF _area <> '' THEN _asset_name := _asset_name || '.' || _area; END IF;
    IF _line <> '' THEN _asset_name := _asset_name || '.' || _line; END IF;
    IF _workcell <> '' THEN _asset_name := _asset_name || '.' || _workcell; END IF;
    IF _origin_id <> '' THEN _asset_name := _asset_name || '.' || _origin_id; END IF;

    -- Zoek bestaand asset
    SELECT id INTO _id FROM asset
    WHERE enterprise = _enterprise
      AND site = _site
      AND area = _area
      AND line = _line
      AND workcell = _workcell
      AND origin_id = _origin_id;

    -- Maak aan als het niet bestaat
    IF _id IS NULL THEN
        INSERT INTO asset (asset_name, enterprise, site, area, line, workcell, origin_id)
        VALUES (_asset_name, _enterprise, _site, _area, _line, _workcell, _origin_id)
        ON CONFLICT (enterprise, site, area, line, workcell, origin_id)
        DO UPDATE SET updated_at = NOW()
        RETURNING id INTO _id;
    END IF;

    RETURN _id;
END;
$$ LANGUAGE plpgsql;
