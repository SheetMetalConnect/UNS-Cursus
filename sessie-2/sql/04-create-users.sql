-- =================================================================
-- STAP 4: Database gebruikers aanmaken
-- =================================================================
-- Twee gebruikers met verschillende rechten:
--
-- 1. kafkatopostgresqlv2 (schrijver)
--    Gebruikt door UMH Core historian flow om data te schrijven
--    Mag: SELECT, INSERT, UPDATE, DELETE + get_asset_id() uitvoeren
--
-- 2. grafanareader (lezer)
--    Gebruikt door Grafana dashboards
--    Mag: alleen SELECT (read-only)
--
-- Waarom aparte gebruikers?
--    Security best practice: least privilege principle
--    Grafana kan nooit per ongeluk data wijzigen of verwijderen
-- =================================================================

-- Writer user (voor UMH Core dataFlows)
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'kafkatopostgresqlv2') THEN
        CREATE ROLE kafkatopostgresqlv2 WITH LOGIN PASSWORD 'umhcore';
    END IF;
END $$;
-- Altijd wachtwoord resetten (voorkomt scram-sha-256 auth problemen)
ALTER ROLE kafkatopostgresqlv2 WITH PASSWORD 'umhcore';

GRANT CONNECT ON DATABASE umh TO kafkatopostgresqlv2;
GRANT USAGE ON SCHEMA public TO kafkatopostgresqlv2;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO kafkatopostgresqlv2;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO kafkatopostgresqlv2;
GRANT EXECUTE ON FUNCTION get_asset_id TO kafkatopostgresqlv2;

-- Reader user (voor Grafana)
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
