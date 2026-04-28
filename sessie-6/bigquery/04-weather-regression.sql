-- ==============================================================================
-- Demo 3: Weer → solar output regressie
-- ==============================================================================
-- Welke weerfactoren bepalen hoeveel stroom je panelen opleveren?
-- Linear regression: voorspel power output op basis van weer
-- ==============================================================================

-- Stap 1: Combineer weer + solar data (join op tijd)
CREATE OR REPLACE VIEW uns_cursus.weather_solar_combined AS
SELECT
  s.time,
  s.dc_power_w AS power_w,
  w.solar_irradiance,
  w.temperature_c,
  w.humidity_pct,
  w.cloud_cover_pct,
  w.wind_speed_kmh
FROM uns_cursus.solar_power s
JOIN uns_cursus.weather w
  ON TIMESTAMP_TRUNC(s.time, MINUTE) = TIMESTAMP_TRUNC(w.time, MINUTE)
WHERE s.dc_power_w IS NOT NULL
  AND w.solar_irradiance IS NOT NULL;

-- Stap 2: Regressiemodel trainen
-- Welke weerfactoren voorspellen de power output het beste?
CREATE OR REPLACE MODEL uns_cursus.weather_power_model
OPTIONS(
  model_type = 'LINEAR_REG',
  input_label_cols = ['power_w']
) AS
SELECT
  power_w,
  solar_irradiance,
  temperature_c,
  humidity_pct,
  cloud_cover_pct,
  wind_speed_kmh
FROM uns_cursus.weather_solar_combined;

-- Stap 3: Model evalueren — hoe goed voorspelt het?
SELECT *
FROM ML.EVALUATE(MODEL uns_cursus.weather_power_model);
-- Kijk naar r2_score: 0.8+ = goed, 0.9+ = zeer goed

-- Stap 4: Feature importance — welke factor telt het meest?
SELECT *
FROM ML.WEIGHTS(MODEL uns_cursus.weather_power_model)
ORDER BY ABS(weight) DESC;
-- solar_irradiance zal waarschijnlijk #1 zijn (logisch)
-- maar cloud_cover en temperature hebben ook invloed

-- Stap 5: Voorspelling met nieuwe weerdata
-- "Het wordt morgen 18 graden, bewolkt, weinig wind — hoeveel stroom?"
SELECT *
FROM ML.PREDICT(MODEL uns_cursus.weather_power_model,
  (SELECT
    500.0 AS solar_irradiance,
    18.0 AS temperature_c,
    60.0 AS humidity_pct,
    40.0 AS cloud_cover_pct,
    5.0 AS wind_speed_kmh));
