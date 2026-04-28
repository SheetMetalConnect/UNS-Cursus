-- ==============================================================================
-- Demo 2: Anomaly detection op machine data
-- ==============================================================================
-- Detecteert ongewone patronen in machine run times
-- Bijvoorbeeld: machine draait te lang, te kort, of onverwachte stilstand
-- ==============================================================================

-- Stap 1: Bekijk de machine data
SELECT time, run_time_sec, down_time_sec, planned_cycle_ms
FROM uns_cursus.machine_production
WHERE run_time_sec IS NOT NULL
ORDER BY time DESC
LIMIT 20;

-- Stap 2: Trainingsdata (run_time als tijdreeks)
CREATE OR REPLACE VIEW uns_cursus.machine_training AS
SELECT
  TIMESTAMP_TRUNC(time, MINUTE) AS time,
  AVG(run_time_sec) AS run_time
FROM uns_cursus.machine_production
WHERE run_time_sec IS NOT NULL
GROUP BY 1
ORDER BY 1;

-- Stap 3: ARIMA model trainen voor anomaly detection
CREATE OR REPLACE MODEL uns_cursus.machine_anomaly_model
OPTIONS(
  model_type = 'ARIMA_PLUS',
  time_series_timestamp_col = 'time',
  time_series_data_col = 'run_time',
  auto_arima = TRUE,
  data_frequency = 'AUTO_FREQUENCY'
) AS
SELECT time, run_time
FROM uns_cursus.machine_training;

-- Stap 4: Anomalieën detecteren
-- is_anomaly = true betekent: deze waarde wijkt significant af
SELECT *
FROM ML.DETECT_ANOMALIES(MODEL uns_cursus.machine_anomaly_model,
  STRUCT(0.95 AS anomaly_prob_threshold),
  (SELECT time, run_time FROM uns_cursus.machine_training))
WHERE is_anomaly = TRUE
ORDER BY time DESC
LIMIT 20;

-- Stap 5: Alle data met anomaly flag (voor dashboard)
SELECT
  time,
  run_time AS actual,
  lower_bound,
  upper_bound,
  is_anomaly,
  anomaly_probability
FROM ML.DETECT_ANOMALIES(MODEL uns_cursus.machine_anomaly_model,
  STRUCT(0.95 AS anomaly_prob_threshold),
  (SELECT time, run_time FROM uns_cursus.machine_training))
ORDER BY time;
