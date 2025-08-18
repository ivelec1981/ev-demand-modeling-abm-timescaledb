-- ==============================================================================
-- sample_data.sql - Sample Data for EV Demand Modeling Framework
-- ==============================================================================
--
-- This script populates the database with sample data for testing and
-- demonstration purposes. It includes realistic EV simulation scenarios
-- and charging infrastructure data.
--
-- Author: Iván Sánchez-Loor, Manuel Ayala-Chauvin
-- Institution: Universidad Indoamérica - SISAu Research Group
-- ==============================================================================

-- Clear existing sample data
DELETE FROM ev_demand_timeseries WHERE simulation_id LIKE 'SAMPLE_%';
DELETE FROM ev_agents WHERE simulation_id LIKE 'SAMPLE_%';
DELETE FROM simulation_summary WHERE simulation_id LIKE 'SAMPLE_%';
DELETE FROM simulation_metadata WHERE simulation_id LIKE 'SAMPLE_%';
DELETE FROM charging_stations WHERE station_name LIKE 'Sample%';
DELETE FROM grid_transformers WHERE transformer_name LIKE 'Sample%';

-- ==============================================================================
-- 1. SAMPLE CHARGING STATIONS
-- ==============================================================================
-- Realistic charging infrastructure for Quito, Ecuador

INSERT INTO charging_stations (
    station_name, location_type, latitude, longitude, 
    charging_power_kw, connector_type, availability_24h, 
    cost_per_kwh, utilization_factor, installation_date, status
) VALUES 
-- Home charging points
('Sample Home Station 1', 'home', -0.1807, -78.4678, 7.4, 'Type 2', TRUE, 0.15, 0.25, '2023-01-15', 'active'),
('Sample Home Station 2', 'home', -0.1950, -78.5000, 3.7, 'Type 2', TRUE, 0.15, 0.30, '2023-02-20', 'active'),
('Sample Home Station 3', 'home', -0.1650, -78.4500, 11.0, 'Type 2', TRUE, 0.15, 0.20, '2023-03-10', 'active'),

-- Work charging stations
('Sample Office Complex A', 'work', -0.1750, -78.4800, 22.0, 'Type 2', FALSE, 0.18, 0.45, '2023-01-01', 'active'),
('Sample Business Park B', 'work', -0.1900, -78.4900, 11.0, 'Type 2', FALSE, 0.20, 0.35, '2023-02-15', 'active'),
('Sample Industrial Zone C', 'work', -0.2100, -78.5100, 7.4, 'Type 2', FALSE, 0.17, 0.40, '2023-03-01', 'active'),

-- Public charging stations
('Sample Mall Quicentro', 'public', -0.1780, -78.4820, 50.0, 'CCS Combo', TRUE, 0.25, 0.60, '2023-01-10', 'active'),
('Sample Parque La Carolina', 'public', -0.1680, -78.4850, 22.0, 'Type 2', TRUE, 0.22, 0.40, '2023-02-01', 'active'),
('Sample Centro Histórico', 'public', -0.2200, -78.5120, 11.0, 'Type 2', TRUE, 0.24, 0.35, '2023-02-20', 'active'),

-- Highway charging stations
('Sample Highway North', 'highway', -0.1000, -78.4000, 150.0, 'CCS Combo', TRUE, 0.30, 0.25, '2023-01-20', 'active'),
('Sample Highway South', 'highway', -0.3000, -78.5500, 150.0, 'CCS Combo', TRUE, 0.30, 0.20, '2023-02-10', 'active');

-- ==============================================================================
-- 2. SAMPLE GRID TRANSFORMERS
-- ==============================================================================
-- Electrical grid infrastructure for Quito area

INSERT INTO grid_transformers (
    transformer_name, latitude, longitude, capacity_kva,
    voltage_primary, voltage_secondary, load_factor_baseline,
    area_served_km2, households_served, installation_year, status
) VALUES 
('Sample Transformer Norte', -0.1500, -78.4500, 500.0, 13800, 240, 0.65, 2.5, 450, 2020, 'operational'),
('Sample Transformer Centro', -0.2000, -78.5000, 750.0, 13800, 240, 0.72, 3.2, 680, 2019, 'operational'),
('Sample Transformer Sur', -0.2500, -78.5200, 300.0, 13800, 240, 0.58, 1.8, 320, 2021, 'operational'),
('Sample Transformer Valle', -0.1800, -78.4800, 1000.0, 13800, 240, 0.68, 4.1, 850, 2018, 'operational'),
('Sample Transformer Cumbayá', -0.1200, -78.4200, 400.0, 13800, 240, 0.45, 2.0, 380, 2022, 'operational');

-- ==============================================================================
-- 3. SAMPLE SIMULATION METADATA
-- ==============================================================================
-- Three different simulation scenarios for testing

INSERT INTO simulation_metadata (
    simulation_id, timestamp, config_json, processing_engine,
    duration_seconds, n_vehicles, n_runs, days_simulated,
    random_seed, status, created_by, notes
) VALUES 
(
    'SAMPLE_SMALL_SIM_001',
    '2024-01-15 10:00:00+00',
    '{
        "vehicles": {
            "num_vehicles": 1000,
            "battery_sizes": [40, 60, 80],
            "charging_powers": [3.7, 7.4, 11, 22]
        },
        "simulation": {
            "days": 7,
            "time_resolution": 15,
            "monte_carlo_runs": 100
        },
        "description": "Small-scale test simulation"
    }'::jsonb,
    'CPU',
    145.5,
    1000,
    100,
    7,
    42,
    'completed',
    'test_user',
    'Small simulation for validation testing'
),
(
    'SAMPLE_MEDIUM_SIM_002', 
    '2024-01-20 14:30:00+00',
    '{
        "vehicles": {
            "num_vehicles": 10000,
            "battery_sizes": [40, 60, 80],
            "charging_powers": [3.7, 7.4, 11, 22]
        },
        "simulation": {
            "days": 30,
            "time_resolution": 15,
            "monte_carlo_runs": 500
        },
        "description": "Medium-scale simulation"
    }'::jsonb,
    'GPU',
    892.3,
    10000,
    500,
    30,
    12345,
    'completed',
    'research_team',
    'Medium simulation with GPU acceleration'
),
(
    'SAMPLE_LARGE_SIM_003',
    '2024-02-01 09:00:00+00',
    '{
        "vehicles": {
            "num_vehicles": 50000,
            "battery_sizes": [40, 60, 80],
            "charging_powers": [3.7, 7.4, 11, 22]
        },
        "simulation": {
            "days": 90,
            "time_resolution": 15,
            "monte_carlo_runs": 1000
        },
        "description": "Large-scale quarterly simulation"
    }'::jsonb,
    'GPU',
    3456.8,
    50000,
    1000,
    90,
    54321,
    'completed',
    'production_system',
    'Large-scale quarterly analysis'
);

-- ==============================================================================
-- 4. SAMPLE EV AGENTS
-- ==============================================================================
-- Generate realistic EV agent populations for each simulation

-- Small simulation agents (1000 vehicles)
INSERT INTO ev_agents (
    simulation_id, agent_id, vehicle_type, battery_capacity, charging_power,
    efficiency, annual_mileage, daily_distance, home_charging, work_charging,
    soc_start_threshold, soc_end_threshold, convenience_factor, time_flexibility
)
SELECT 
    'SAMPLE_SMALL_SIM_001' AS simulation_id,
    generate_series(1, 1000) AS agent_id,
    (ARRAY['compact', 'sedan', 'suv'])[1 + (random() * 2)::int] AS vehicle_type,
    (ARRAY[40, 60, 80])[1 + (random() * 2)::int]::numeric AS battery_capacity,
    (ARRAY[3.7, 7.4, 11, 22])[1 + (random() * 3)::int]::numeric AS charging_power,
    (6.0 + random() * 2.0)::numeric(4,1) AS efficiency,
    (12000 + random() * 8000)::numeric(8,1) AS annual_mileage,
    (30 + random() * 20)::numeric(6,1) AS daily_distance,
    (random() < 0.7) AS home_charging,
    (random() < 0.4) AS work_charging,
    (0.2 + random() * 0.2)::numeric(3,2) AS soc_start_threshold,
    (0.8 + random() * 0.2)::numeric(3,2) AS soc_end_threshold,
    (0.6 + random() * 0.4)::numeric(3,2) AS convenience_factor,
    (0.3 + random() * 0.5)::numeric(3,2) AS time_flexibility;

-- Medium simulation agents (10000 vehicles) - subset for demo
INSERT INTO ev_agents (
    simulation_id, agent_id, vehicle_type, battery_capacity, charging_power,
    efficiency, annual_mileage, daily_distance, home_charging, work_charging,
    soc_start_threshold, soc_end_threshold, convenience_factor, time_flexibility
)
SELECT 
    'SAMPLE_MEDIUM_SIM_002' AS simulation_id,
    generate_series(1, 500) AS agent_id, -- Only inserting 500 for demo
    (ARRAY['compact', 'sedan', 'suv'])[1 + (random() * 2)::int] AS vehicle_type,
    (ARRAY[40, 60, 80])[1 + (random() * 2)::int]::numeric AS battery_capacity,
    (ARRAY[3.7, 7.4, 11, 22])[1 + (random() * 3)::int]::numeric AS charging_power,
    (6.0 + random() * 2.0)::numeric(4,1) AS efficiency,
    (15000 + random() * 10000)::numeric(8,1) AS annual_mileage,
    (35 + random() * 25)::numeric(6,1) AS daily_distance,
    (random() < 0.75) AS home_charging,
    (random() < 0.45) AS work_charging,
    (0.15 + random() * 0.25)::numeric(3,2) AS soc_start_threshold,
    (0.85 + random() * 0.15)::numeric(3,2) AS soc_end_threshold,
    (0.5 + random() * 0.5)::numeric(3,2) AS convenience_factor,
    (0.2 + random() * 0.6)::numeric(3,2) AS time_flexibility;

-- ==============================================================================
-- 5. SAMPLE SIMULATION SUMMARIES
-- ==============================================================================

INSERT INTO simulation_summary (
    simulation_id, total_runs, mean_daily_demand, peak_demand, min_demand,
    load_factor, demand_std_dev, coincidence_factor_avg, peak_hour, valley_hour,
    energy_total_kwh, carbon_impact_kg, grid_stress_index, validation_mape
) VALUES 
(
    'SAMPLE_SMALL_SIM_001',
    100,
    285.6,    -- kW average daily demand
    489.2,    -- kW peak demand
    45.8,     -- kW minimum demand
    0.584,    -- Load factor
    87.3,     -- Standard deviation
    0.258,    -- Average coincidence factor
    19,       -- Peak hour (7 PM)
    4,        -- Valley hour (4 AM)
    2056.3,   -- Total energy kWh
    823.4,    -- Carbon impact kg
    3.2,      -- Grid stress index
    4.2       -- Validation MAPE
),
(
    'SAMPLE_MEDIUM_SIM_002',
    500,
    2847.5,   -- kW average daily demand
    4892.1,   -- kW peak demand
    458.3,    -- kW minimum demand
    0.582,    -- Load factor
    673.2,    -- Standard deviation
    0.225,    -- Average coincidence factor
    19,       -- Peak hour
    3,        -- Valley hour
    20541.0,  -- Total energy kWh
    8216.4,   -- Carbon impact kg
    6.8,      -- Grid stress index
    3.8       -- Validation MAPE
),
(
    'SAMPLE_LARGE_SIM_003',
    1000,
    14238.7,  -- kW average daily demand
    22461.5,  -- kW peak demand
    2291.4,   -- kW minimum demand
    0.635,    -- Load factor
    2984.6,   -- Standard deviation
    0.198,    -- Average coincidence factor
    20,       -- Peak hour
    4,        -- Valley hour
    102785.0, -- Total energy kWh
    41114.0,  -- Carbon impact kg
    8.9,      -- Grid stress index
    4.5       -- Validation MAPE
);

-- ==============================================================================
-- 6. SAMPLE TIME-SERIES DATA
-- ==============================================================================
-- Generate realistic demand patterns for demonstration

-- Helper function to generate realistic demand curve
CREATE OR REPLACE FUNCTION generate_hourly_demand_factor(hour_of_day INTEGER)
RETURNS NUMERIC AS $$
BEGIN
    -- Typical daily demand pattern for EV charging
    RETURN CASE 
        WHEN hour_of_day BETWEEN 0 AND 5 THEN 0.3 + random() * 0.2  -- Night: low demand
        WHEN hour_of_day BETWEEN 6 AND 8 THEN 0.4 + random() * 0.3  -- Morning: moderate
        WHEN hour_of_day BETWEEN 9 AND 17 THEN 0.6 + random() * 0.2 -- Work hours: moderate-high
        WHEN hour_of_day BETWEEN 18 AND 22 THEN 0.8 + random() * 0.4 -- Evening: peak
        ELSE 0.5 + random() * 0.3  -- Other hours
    END;
END;
$$ LANGUAGE plpgsql;

-- Generate sample time-series data for small simulation (1 week)
INSERT INTO ev_demand_timeseries (
    simulation_id, run_id, timestamp, total_demand, raw_demand, 
    coincidence_factor, n_vehicles, n_charging_vehicles, peak_demand_flag
)
SELECT 
    'SAMPLE_SMALL_SIM_001',
    1, -- Single run for demo
    ts.timestamp,
    (285.6 * generate_hourly_demand_factor(EXTRACT(hour FROM ts.timestamp)::int) * (0.8 + random() * 0.4))::numeric(12,3),
    (285.6 * generate_hourly_demand_factor(EXTRACT(hour FROM ts.timestamp)::int) * (0.8 + random() * 0.4) / 0.258)::numeric(12,3),
    calculate_coincidence_factor(1000),
    1000,
    (150 + random() * 200)::int,
    FALSE  -- Will be updated by trigger
FROM generate_series(
    '2024-01-15 00:00:00'::timestamp,
    '2024-01-21 23:45:00'::timestamp,
    '15 minutes'::interval
) AS ts(timestamp);

-- Update peak demand flags
UPDATE ev_demand_timeseries 
SET peak_demand_flag = TRUE
WHERE simulation_id = 'SAMPLE_SMALL_SIM_001' 
  AND total_demand > (
    SELECT AVG(total_demand) + 2 * STDDEV(total_demand) 
    FROM ev_demand_timeseries 
    WHERE simulation_id = 'SAMPLE_SMALL_SIM_001'
  );

-- Generate abbreviated time-series for medium simulation (first 3 days)
INSERT INTO ev_demand_timeseries (
    simulation_id, run_id, timestamp, total_demand, raw_demand,
    coincidence_factor, n_vehicles, n_charging_vehicles, peak_demand_flag
)
SELECT 
    'SAMPLE_MEDIUM_SIM_002',
    (random() * 5 + 1)::int, -- Random run IDs 1-5
    ts.timestamp,
    (2847.5 * generate_hourly_demand_factor(EXTRACT(hour FROM ts.timestamp)::int) * (0.85 + random() * 0.3))::numeric(12,3),
    (2847.5 * generate_hourly_demand_factor(EXTRACT(hour FROM ts.timestamp)::int) * (0.85 + random() * 0.3) / 0.225)::numeric(12,3),
    calculate_coincidence_factor(10000),
    10000,
    (1200 + random() * 800)::int,
    FALSE
FROM generate_series(
    '2024-01-20 00:00:00'::timestamp,
    '2024-01-22 23:45:00'::timestamp,
    '15 minutes'::interval
) AS ts(timestamp);

-- ==============================================================================
-- 7. SAMPLE FORECAST DATA
-- ==============================================================================
-- Generate sample forecasted demand for comparison

INSERT INTO demand_forecasts (
    timestamp, forecast_type, forecasted_demand, 
    confidence_interval_lower, confidence_interval_upper,
    model_version
)
SELECT 
    ts.timestamp,
    'neural_network',
    (300.0 * generate_hourly_demand_factor(EXTRACT(hour FROM ts.timestamp)::int) * (0.9 + random() * 0.2))::numeric(12,3),
    (300.0 * generate_hourly_demand_factor(EXTRACT(hour FROM ts.timestamp)::int) * (0.9 + random() * 0.2) * 0.85)::numeric(12,3),
    (300.0 * generate_hourly_demand_factor(EXTRACT(hour FROM ts.timestamp)::int) * (0.9 + random() * 0.2) * 1.15)::numeric(12,3),
    'v1.2.0'
FROM generate_series(
    '2024-01-15 00:00:00'::timestamp,
    '2024-01-21 23:45:00'::timestamp,
    '15 minutes'::interval
) AS ts(timestamp);

-- ARIMA forecasts
INSERT INTO demand_forecasts (
    timestamp, forecast_type, forecasted_demand,
    confidence_interval_lower, confidence_interval_upper,
    model_version
)
SELECT 
    ts.timestamp,
    'arima',
    (295.0 * generate_hourly_demand_factor(EXTRACT(hour FROM ts.timestamp)::int) * (0.88 + random() * 0.24))::numeric(12,3),
    (295.0 * generate_hourly_demand_factor(EXTRACT(hour FROM ts.timestamp)::int) * (0.88 + random() * 0.24) * 0.82)::numeric(12,3),
    (295.0 * generate_hourly_demand_factor(EXTRACT(hour FROM ts.timestamp)::int) * (0.88 + random() * 0.24) * 1.18)::numeric(12,3),
    'v2.1.0'
FROM generate_series(
    '2024-01-15 00:00:00'::timestamp,
    '2024-01-21 23:45:00'::timestamp,
    '1 hour'::interval
) AS ts(timestamp);

-- ==============================================================================
-- 8. REFRESH CONTINUOUS AGGREGATES
-- ==============================================================================
-- Refresh continuous aggregates to include sample data

CALL refresh_continuous_aggregate('daily_demand_summary', '2024-01-01', '2024-02-28');
CALL refresh_continuous_aggregate('hourly_demand_summary', '2024-01-01', '2024-02-28');
CALL refresh_continuous_aggregate('weekly_demand_patterns', '2024-01-01', '2024-02-28');

-- ==============================================================================
-- 9. VALIDATION QUERIES
-- ==============================================================================
-- Validate sample data integrity

-- Check simulation metadata
SELECT 
    simulation_id,
    n_vehicles,
    n_runs,
    days_simulated,
    status
FROM simulation_metadata 
WHERE simulation_id LIKE 'SAMPLE_%'
ORDER BY simulation_id;

-- Check agent counts
SELECT 
    simulation_id,
    COUNT(*) as agent_count,
    AVG(battery_capacity) as avg_battery,
    AVG(charging_power) as avg_power
FROM ev_agents 
WHERE simulation_id LIKE 'SAMPLE_%'
GROUP BY simulation_id
ORDER BY simulation_id;

-- Check time-series data
SELECT 
    simulation_id,
    COUNT(*) as data_points,
    MIN(timestamp) as start_time,
    MAX(timestamp) as end_time,
    AVG(total_demand) as avg_demand,
    MAX(total_demand) as peak_demand
FROM ev_demand_timeseries 
WHERE simulation_id LIKE 'SAMPLE_%'
GROUP BY simulation_id
ORDER BY simulation_id;

-- Check charging stations
SELECT 
    location_type,
    COUNT(*) as station_count,
    AVG(charging_power_kw) as avg_power,
    AVG(utilization_factor) as avg_utilization
FROM charging_stations 
WHERE station_name LIKE 'Sample%'
GROUP BY location_type
ORDER BY location_type;

-- ==============================================================================
-- 10. SAMPLE QUERIES FOR TESTING
-- ==============================================================================

-- Example query 1: Peak demand analysis
SELECT 
    simulation_id,
    DATE(timestamp) as date,
    MAX(total_demand) as daily_peak,
    MIN(total_demand) as daily_min,
    AVG(total_demand) as daily_avg
FROM ev_demand_timeseries
WHERE simulation_id = 'SAMPLE_SMALL_SIM_001'
GROUP BY simulation_id, DATE(timestamp)
ORDER BY date;

-- Example query 2: Hourly demand patterns
SELECT 
    EXTRACT(hour FROM timestamp) as hour,
    AVG(total_demand) as avg_demand,
    STDDEV(total_demand) as std_demand,
    COUNT(*) as observations
FROM ev_demand_timeseries
WHERE simulation_id = 'SAMPLE_SMALL_SIM_001'
GROUP BY EXTRACT(hour FROM timestamp)
ORDER BY hour;

-- Example query 3: Agent characteristics distribution
SELECT 
    vehicle_type,
    battery_capacity,
    COUNT(*) as count,
    AVG(daily_distance) as avg_distance
FROM ev_agents
WHERE simulation_id = 'SAMPLE_SMALL_SIM_001'
GROUP BY vehicle_type, battery_capacity
ORDER BY vehicle_type, battery_capacity;

-- Clean up helper function
DROP FUNCTION IF EXISTS generate_hourly_demand_factor(INTEGER);

-- ==============================================================================
-- SAMPLE DATA LOADING COMPLETE
-- ==============================================================================

SELECT 
    'Sample data loading completed successfully' AS status,
    NOW() AS timestamp,
    (
        SELECT COUNT(*) FROM simulation_metadata WHERE simulation_id LIKE 'SAMPLE_%'
    ) AS sample_simulations,
    (
        SELECT COUNT(*) FROM ev_agents WHERE simulation_id LIKE 'SAMPLE_%'  
    ) AS sample_agents,
    (
        SELECT COUNT(*) FROM ev_demand_timeseries WHERE simulation_id LIKE 'SAMPLE_%'
    ) AS sample_timeseries_points,
    (
        SELECT COUNT(*) FROM charging_stations WHERE station_name LIKE 'Sample%'
    ) AS sample_stations;

-- End of sample_data.sql