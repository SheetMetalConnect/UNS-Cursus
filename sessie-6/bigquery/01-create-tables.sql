-- ==============================================================================
-- Sessie 6 — BigQuery tabellen aanmaken
-- ==============================================================================
-- Voer uit in BigQuery Console → Query editor
-- Dataset: uns_cursus (maak eerst aan via BigQuery Console)
-- ==============================================================================

-- Solar vermogen (1-minuut aggregatie)
CREATE TABLE IF NOT EXISTS uns_cursus.solar_power (
  time TIMESTAMP,
  dc_power_w FLOAT64,
  ac_power_w FLOAT64,
  panel_temp_c FLOAT64,
  grid_freq_hz FLOAT64,
  daily_yield_kwh FLOAT64
);

-- Weer (5-minuut aggregatie)
CREATE TABLE IF NOT EXISTS uns_cursus.weather (
  time TIMESTAMP,
  solar_irradiance FLOAT64,
  temperature_c FLOAT64,
  humidity_pct FLOAT64,
  cloud_cover_pct FLOAT64,
  wind_speed_kmh FLOAT64,
  pressure_hpa FLOAT64
);

-- Machine productie (1-minuut aggregatie)
CREATE TABLE IF NOT EXISTS uns_cursus.machine_production (
  time TIMESTAMP,
  run_time_sec FLOAT64,
  down_time_sec FLOAT64,
  planned_cycle_ms FLOAT64,
  downstream_blocked FLOAT64
);
