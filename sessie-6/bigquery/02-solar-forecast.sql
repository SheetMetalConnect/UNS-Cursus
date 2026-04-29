-- ==============================================================================
-- Demo 1: Solar vermogen voorspellen (ARIMA_PLUS)
-- ==============================================================================
-- Voorspelt de DC power output voor de komende 24 uur
-- op basis van historische patronen (dag/nacht cyclus, weer)
-- ==============================================================================

-- Stap 1: Bekijk de data
SELECT time, daily_yield_kwh, panel_temp_c
FROM uns_cursus.solar_power
WHERE daily_yield_kwh IS NOT NULL
ORDER BY time DESC
LIMIT 20;

-- Stap 2: Trainingsdata klaarzetten (per minuut)
CREATE OR REPLACE VIEW uns_cursus.solar_training AS
SELECT
  TIMESTAMP_TRUNC(time, MINUTE) AS time,
  AVG(daily_yield_kwh) AS yield_kwh
FROM uns_cursus.solar_power
WHERE daily_yield_kwh IS NOT NULL
GROUP BY 1
ORDER BY 1;

-- Stap 3: Model trainen
-- ARIMA_PLUS detecteert automatisch seizoenspatronen (dag/nacht)
CREATE OR REPLACE MODEL uns_cursus.solar_forecast_model
OPTIONS(
  model_type = 'ARIMA_PLUS',
  time_series_timestamp_col = 'time',
  time_series_data_col = 'yield_kwh',
  auto_arima = TRUE,
  data_frequency = 'AUTO_FREQUENCY'
) AS
SELECT time, yield_kwh
FROM uns_cursus.solar_training;

-- Stap 4: Voorspelling maken (komende 24 uur = 1440 minuten)
SELECT *
FROM ML.FORECAST(MODEL uns_cursus.solar_forecast_model,
  STRUCT(1440 AS horizon, 0.9 AS confidence_level));

-- Stap 5: Voorspelling visualiseren (historisch + forecast)
SELECT
  time AS timestamp,
  yield_kwh AS actual,
  NULL AS forecast,
  NULL AS lower_bound,
  NULL AS upper_bound
FROM uns_cursus.solar_training
WHERE time > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 2 DAY)

UNION ALL

SELECT
  forecast_timestamp AS timestamp,
  NULL AS actual,
  forecast_value AS forecast,
  prediction_interval_lower_bound AS lower_bound,
  prediction_interval_upper_bound AS upper_bound
FROM ML.FORECAST(MODEL uns_cursus.solar_forecast_model,
  STRUCT(480 AS horizon, 0.9 AS confidence_level))
ORDER BY timestamp;
