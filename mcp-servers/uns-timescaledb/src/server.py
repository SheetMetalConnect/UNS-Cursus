"""
UNS TimescaleDB MCP Server
===========================
Geeft Claude toegang tot de UNS historian database (TimescaleDB).

Tabellen:
  - asset              ISA-95 equipment hierarchy
  - tag                Numerieke sensordata (hypertable)
  - tag_string         Tekst sensordata (hypertable)
  - erp_sales_order    Sales orders
  - erp_work_order     Werkorders (huidige staat)
  - erp_work_order_history  Werkorder audit trail
  - production_orders  Production orders (sessie 4)
"""

import json
import os
from contextlib import asynccontextmanager
from datetime import datetime, timedelta

import asyncpg
from mcp.server.fastmcp import FastMCP

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
DB_DSN = os.environ.get(
    "UNS_DB_DSN",
    "postgresql://grafanareader:changeme@localhost:5432/umh",
)

# ---------------------------------------------------------------------------
# Lifespan — connection pool
# ---------------------------------------------------------------------------
@asynccontextmanager
async def lifespan(server: FastMCP):
    """Create a connection pool on startup, close on shutdown."""
    pool = await asyncpg.create_pool(DB_DSN, min_size=1, max_size=5)
    try:
        yield {"pool": pool}
    finally:
        await pool.close()


mcp = FastMCP(
    name="uns-timescaledb",
    instructions=(
        "Je bent verbonden met een TimescaleDB historian database van een metaalbewerkingsbedrijf. "
        "De database bevat sensordata (tag/tag_string tabellen), assets (ISA-95 hiërarchie), "
        "sales orders, werkorders en production orders. "
        "Gebruik de tools om data op te vragen. Alle queries zijn read-only."
    ),
    lifespan=lifespan,
)

# ---------------------------------------------------------------------------
# Helper
# ---------------------------------------------------------------------------
def rows_to_text(rows: list[asyncpg.Record], max_rows: int = 200) -> str:
    """Convert asyncpg rows to readable text."""
    if not rows:
        return "Geen resultaten."
    # Convert to list of dicts
    result = []
    for row in rows[:max_rows]:
        d = {}
        for key, val in row.items():
            if isinstance(val, datetime):
                d[key] = val.isoformat()
            else:
                d[key] = val
        result.append(d)
    text = json.dumps(result, indent=2, ensure_ascii=False, default=str)
    if len(rows) > max_rows:
        text += f"\n\n... en nog {len(rows) - max_rows} rijen (niet getoond)"
    return text


# ===========================================================================
# Resources
# ===========================================================================

SCHEMA_TEXT = """
## Database Schema — UNS Historian (TimescaleDB)

### asset
Equipment/device metadata (ISA-95 hiërarchie):
  id SERIAL PK, asset_name VARCHAR(255) UNIQUE,
  location, enterprise, site, area, line, workcell, origin_id,
  created_at, updated_at

### tag (hypertable)
Numerieke sensordata:
  time TIMESTAMPTZ, asset_id INT FK→asset, tag_name VARCHAR(255),
  value DOUBLE PRECISION, origin VARCHAR(255)

### tag_string (hypertable)
Tekst sensordata:
  time TIMESTAMPTZ, asset_id INT FK→asset, tag_name VARCHAR(255),
  value TEXT, origin VARCHAR(255)

### erp_sales_order
Sales orders:
  order_id TEXT PK, asset_id INT FK→asset,
  customer_name, milestone, due_date, order_date, delivered_date,
  status, change_type, created_at, updated_at

### erp_work_order
Werkorders (huidige staat):
  order_nr TEXT PK, asset_id INT FK→asset,
  product, qty INT, customer, priority INT,
  due_date, status, change_type, created_at, updated_at

### erp_work_order_history
Werkorder audit trail (append-only):
  history_id BIGSERIAL PK, order_nr, asset_id, product, qty,
  customer, priority, due_date, status, change_type, recorded_at

### production_orders
Productieorders (sessie 4):
  id SERIAL PK, timestamp, asset_id FK→asset, order_id UNIQUE,
  customer, part_number, part_description, quantity, quantity_completed,
  quantity_scrap, priority, status, due_date, started_at, completed_at,
  planned_cycle_time_ms, created_at, updated_at
"""


@mcp.resource("uns://schema")
def get_schema() -> str:
    """Database schema overview — alle tabellen en kolommen."""
    return SCHEMA_TEXT


@mcp.resource("uns://assets")
async def get_assets() -> str:
    """Lijst van alle assets in de ISA-95 hiërarchie."""
    pool: asyncpg.Pool = mcp.get_context().lifespan_context["pool"]
    async with pool.acquire() as conn:
        rows = await conn.fetch(
            "SELECT id, asset_name, enterprise, site, area, line, workcell "
            "FROM asset ORDER BY asset_name"
        )
    return rows_to_text(rows)


# ===========================================================================
# Tools
# ===========================================================================

@mcp.tool()
async def query_sensors(
    asset_name: str | None = None,
    tag_name: str | None = None,
    hours: int = 1,
    limit: int = 100,
) -> str:
    """Query sensor readings from the tag table.

    Args:
        asset_name: Filter by asset name (e.g. 'smc.vienna.cnc-1'). Supports LIKE patterns with %.
        tag_name: Filter by tag/sensor name (e.g. 'temperature', 'vibration'). Supports LIKE patterns.
        hours: How many hours back to look (default: 1).
        limit: Maximum number of rows to return (default: 100, max: 500).
    """
    pool: asyncpg.Pool = mcp.get_context().lifespan_context["pool"]
    limit = min(limit, 500)

    conditions = ["t.time > NOW() - $1::interval"]
    params: list = [timedelta(hours=hours)]
    idx = 2

    if asset_name:
        conditions.append(f"a.asset_name LIKE ${idx}")
        params.append(asset_name)
        idx += 1

    if tag_name:
        conditions.append(f"t.tag_name LIKE ${idx}")
        params.append(tag_name)
        idx += 1

    where = " AND ".join(conditions)
    query = f"""
        SELECT t.time, a.asset_name, t.tag_name, t.value, t.origin
        FROM tag t
        JOIN asset a ON a.id = t.asset_id
        WHERE {where}
        ORDER BY t.time DESC
        LIMIT {limit}
    """

    async with pool.acquire() as conn:
        rows = await conn.fetch(query, *params)
    return rows_to_text(rows)


@mcp.tool()
async def query_work_orders(
    status: str | None = None,
    customer: str | None = None,
    limit: int = 50,
) -> str:
    """Query current work orders (erp_work_order table).

    Args:
        status: Filter by status (e.g. 'IN_PROGRESS', 'COMPLETED', 'CREATED').
        customer: Filter by customer name. Supports LIKE patterns.
        limit: Maximum rows (default: 50, max: 200).
    """
    pool: asyncpg.Pool = mcp.get_context().lifespan_context["pool"]
    limit = min(limit, 200)

    conditions = []
    params: list = []
    idx = 1

    if status:
        conditions.append(f"w.status = ${idx}")
        params.append(status)
        idx += 1

    if customer:
        conditions.append(f"w.customer LIKE ${idx}")
        params.append(customer)
        idx += 1

    where = "WHERE " + " AND ".join(conditions) if conditions else ""
    query = f"""
        SELECT w.order_nr, a.asset_name, w.product, w.qty, w.customer,
               w.priority, w.due_date, w.status, w.change_type, w.updated_at
        FROM erp_work_order w
        JOIN asset a ON a.id = w.asset_id
        {where}
        ORDER BY w.updated_at DESC
        LIMIT {limit}
    """

    async with pool.acquire() as conn:
        rows = await conn.fetch(query, *params)
    return rows_to_text(rows)


@mcp.tool()
async def query_work_order_history(
    order_nr: str | None = None,
    hours: int = 24,
    limit: int = 100,
) -> str:
    """Query work order audit trail (erp_work_order_history table).

    Args:
        order_nr: Filter by specific order number.
        hours: How many hours back to look (default: 24).
        limit: Maximum rows (default: 100, max: 500).
    """
    pool: asyncpg.Pool = mcp.get_context().lifespan_context["pool"]
    limit = min(limit, 500)

    conditions = ["h.recorded_at > NOW() - $1::interval"]
    params: list = [timedelta(hours=hours)]
    idx = 2

    if order_nr:
        conditions.append(f"h.order_nr = ${idx}")
        params.append(order_nr)
        idx += 1

    where = " AND ".join(conditions)
    query = f"""
        SELECT h.history_id, h.order_nr, a.asset_name, h.product, h.qty,
               h.customer, h.priority, h.due_date, h.status,
               h.change_type, h.recorded_at
        FROM erp_work_order_history h
        JOIN asset a ON a.id = h.asset_id
        WHERE {where}
        ORDER BY h.recorded_at DESC
        LIMIT {limit}
    """

    async with pool.acquire() as conn:
        rows = await conn.fetch(query, *params)
    return rows_to_text(rows)


@mcp.tool()
async def query_sales_orders(
    status: str | None = None,
    customer_name: str | None = None,
    limit: int = 50,
) -> str:
    """Query sales orders (erp_sales_order table).

    Args:
        status: Filter by status.
        customer_name: Filter by customer name. Supports LIKE patterns.
        limit: Maximum rows (default: 50, max: 200).
    """
    pool: asyncpg.Pool = mcp.get_context().lifespan_context["pool"]
    limit = min(limit, 200)

    conditions = []
    params: list = []
    idx = 1

    if status:
        conditions.append(f"s.status = ${idx}")
        params.append(status)
        idx += 1

    if customer_name:
        conditions.append(f"s.customer_name LIKE ${idx}")
        params.append(customer_name)
        idx += 1

    where = "WHERE " + " AND ".join(conditions) if conditions else ""
    query = f"""
        SELECT s.order_id, a.asset_name, s.customer_name, s.milestone,
               s.due_date, s.order_date, s.delivered_date, s.status, s.updated_at
        FROM erp_sales_order s
        JOIN asset a ON a.id = s.asset_id
        {where}
        ORDER BY s.updated_at DESC
        LIMIT {limit}
    """

    async with pool.acquire() as conn:
        rows = await conn.fetch(query, *params)
    return rows_to_text(rows)


@mcp.tool()
async def list_assets() -> str:
    """List all assets in the ISA-95 hierarchy."""
    pool: asyncpg.Pool = mcp.get_context().lifespan_context["pool"]
    async with pool.acquire() as conn:
        rows = await conn.fetch(
            "SELECT id, asset_name, enterprise, site, area, line, workcell, origin_id "
            "FROM asset ORDER BY asset_name"
        )
    return rows_to_text(rows)


@mcp.tool()
async def query_custom(sql: str) -> str:
    """Run a custom read-only SQL query against the UNS database.

    The database user is read-only (grafanareader) so INSERT/UPDATE/DELETE will fail.
    Use this for advanced queries that the other tools don't cover.

    Args:
        sql: A SELECT query to execute. Only SELECT statements are allowed.
    """
    # Basic safety check
    stripped = sql.strip().upper()
    if not stripped.startswith("SELECT") and not stripped.startswith("WITH"):
        return "Error: alleen SELECT of WITH (CTE) queries zijn toegestaan."

    pool: asyncpg.Pool = mcp.get_context().lifespan_context["pool"]
    async with pool.acquire() as conn:
        try:
            rows = await conn.fetch(sql)
        except Exception as e:
            return f"Query error: {e}"
    return rows_to_text(rows)


# ===========================================================================
# Prompts
# ===========================================================================

@mcp.prompt()
def factory_overview() -> str:
    """Geef een overzicht van de fabriek — welke assets, hoeveel sensordata, open orders."""
    return (
        "Geef mij een compleet overzicht van de fabriek. Doe het volgende:\n"
        "1. Lees eerst het schema (uns://schema resource)\n"
        "2. Lijst alle assets op met list_assets\n"
        "3. Hoeveel sensormetingen zijn er in het laatste uur? (query_custom)\n"
        "4. Welke werkorders zijn er open? (query_work_orders met status IN_PROGRESS of CREATED)\n"
        "5. Welke sales orders staan er open?\n"
        "6. Vat alles samen in een duidelijk overzicht."
    )


@mcp.prompt()
def sensor_analysis(asset_name: str, tag_name: str) -> str:
    """Analyseer sensordata voor een specifieke asset en tag."""
    return (
        f"Analyseer de sensordata voor asset '{asset_name}', tag '{tag_name}'.\n"
        "1. Haal de laatste 500 metingen op\n"
        "2. Bereken gemiddelde, min, max, standaardafwijking\n"
        "3. Zijn er uitschieters of trends?\n"
        "4. Geef een samenvatting geschikt voor een productieleider."
    )


@mcp.prompt()
def order_tracking(order_nr: str) -> str:
    """Volg een werkorder door het hele systeem."""
    return (
        f"Volg werkorder '{order_nr}' door het hele systeem.\n"
        "1. Zoek de huidige staat in erp_work_order\n"
        "2. Haal de volledige history op\n"
        "3. Koppel aan de bijbehorende sales order (als die er is)\n"
        "4. Toon een tijdlijn van alle statuswijzigingen."
    )


# ===========================================================================
# Entry point
# ===========================================================================

def main():
    mcp.run(transport="stdio")


if __name__ == "__main__":
    main()
