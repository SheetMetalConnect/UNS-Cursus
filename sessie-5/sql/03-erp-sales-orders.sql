-- ==============================================================================
-- Sessie 5, Deel 1 — Sales Orders (eenvoudige API-ingest)
-- ==============================================================================
-- Voer dit script uit in DBeaver (localhost:5432/umh, postgres/changeme)
--
-- Maakt aan:
--   1. erp_sales_order — huidige staat van elke sales order (upsert)
--
-- Dit is de eenvoudige variant: alleen de huidige staat, geen history.
-- In Deel 2 (werk orders) voegen we deduplicatie en history tracking toe.
-- ==============================================================================

CREATE TABLE IF NOT EXISTS erp_sales_order (
    order_id TEXT NOT NULL,
    asset_id INTEGER NOT NULL REFERENCES asset(id) ON DELETE CASCADE,
    customer_name TEXT,
    milestone TEXT,
    due_date TIMESTAMPTZ,
    order_date TIMESTAMPTZ,
    delivered_date TIMESTAMPTZ,
    status TEXT,
    change_type TEXT NOT NULL DEFAULT 'UPSERT',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (order_id, asset_id)
);

-- Auto-update timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tr_erp_sales_order_updated ON erp_sales_order;
CREATE TRIGGER tr_erp_sales_order_updated BEFORE UPDATE ON erp_sales_order
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE INDEX IF NOT EXISTS idx_erp_sales_order_status ON erp_sales_order (status);

-- Rechten
GRANT SELECT, INSERT, UPDATE, DELETE ON erp_sales_order TO kafkatopostgresqlv2;
GRANT SELECT ON erp_sales_order TO grafanareader;
