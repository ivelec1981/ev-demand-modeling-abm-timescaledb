-- ==============================================================================
-- schema_original_aligned.sql - Schema Aligned with Original Code
-- ==============================================================================
--
-- This schema is specifically aligned with the original EV simulation code
-- that saves to "ev_simulation_results_final" table
--
-- Author: Iván Sánchez-Loor, Manuel Ayala-Chauvin
-- ==============================================================================

-- Enable TimescaleDB extension
CREATE EXTENSION IF NOT EXISTS timescaledb;

-- Drop existing table if it exists
DROP TABLE IF EXISTS ev_simulation_results_final CASCADE;

-- ==============================================================================
-- MAIN SIMULATION RESULTS TABLE (ALIGNED WITH ORIGINAL CODE)
-- ==============================================================================
-- This is the primary table where the original code saves batch results
CREATE TABLE ev_simulation_results_final (
    -- Temporal dimensions
    year INTEGER NOT NULL,
    month INTEGER NOT NULL CHECK (month BETWEEN 1 AND 12),
    quarter_hour_timestamp TIMESTAMPTZ NOT NULL,
    cuarto_hora_index INTEGER NOT NULL CHECK (cuarto_hora_index BETWEEN 1 AND 96),
    
    -- Geographical dimensions  
    canton_id INTEGER,
    canton_name VARCHAR(100),
    province VARCHAR(50),
    
    -- Simulation parameters
    projection_type VARCHAR(20) CHECK (projection_type IN ('Conservative', 'Base', 'Optimistic')),
    theoretical_active_vehicles INTEGER DEFAULT 0,
    charging_events INTEGER DEFAULT 0,
    charging_probability NUMERIC(5,4) DEFAULT 0,
    
    -- Energy and power metrics
    total_energy_for_interval NUMERIC(12,3) DEFAULT 0 CHECK (total_energy_for_interval >= 0),
    avg_power_for_interval NUMERIC(12,3) DEFAULT 0 CHECK (avg_power_for_interval >= 0),
    peak_power_kw NUMERIC(10,3) DEFAULT 0,
    
    -- Vehicle characteristics (aggregated)
    avg_soc_initial_for_interval NUMERIC(5,2),
    avg_soc_target_for_interval NUMERIC(5,2),
    battery_chemistry VARCHAR(20),
    avg_max_ac_power_kw NUMERIC(6,1),
    
    -- Environmental factors
    avg_temperature_c NUMERIC(4,1) DEFAULT 18.0,
    energy_efficiency_factor NUMERIC(4,3) DEFAULT 1.0 CHECK (energy_efficiency_factor BETWEEN 0.5 AND 1.2),
    
    -- Economic factors
    tariff_usd_per_kwh NUMERIC(8,6),
    electricity_cost_usd NUMERIC(10,4) DEFAULT 0,
    day_type VARCHAR(10) CHECK (day_type IN ('Weekday', 'Weekend')),
    
    -- Technical factors
    vehicle_age_years INTEGER DEFAULT 0 CHECK (vehicle_age_years >= 0),
    battery_degradation_factor NUMERIC(4,3) DEFAULT 1.0 CHECK (battery_degradation_factor BETWEEN 0.7 AND 1.0),
    seasonal_adjustment_factor NUMERIC(4,3) DEFAULT 1.0,
    
    -- Metadata
    run_name VARCHAR(100),
    processing_engine VARCHAR(20) CHECK (processing_engine IN ('CPU', 'GPU', 'PARALLEL-CPU', 'PARALLEL-GPU')),
    batch_number INTEGER,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Composite primary key
    PRIMARY KEY (quarter_hour_timestamp, canton_id, projection_type, run_name)
);

-- Convert to hypertable (partitioned by time)
SELECT create_hypertable('ev_simulation_results_final', 'quarter_hour_timestamp', 
                        chunk_time_interval => INTERVAL '1 week');

-- ==============================================================================
-- INDEXES FOR PERFORMANCE
-- ==============================================================================

-- Primary query patterns from original code
CREATE INDEX idx_ev_results_timestamp ON ev_simulation_results_final(quarter_hour_timestamp);
CREATE INDEX idx_ev_results_year_month ON ev_simulation_results_final(year, month);
CREATE INDEX idx_ev_results_canton ON ev_simulation_results_final(canton_id, canton_name);
CREATE INDEX idx_ev_results_projection ON ev_simulation_results_final(projection_type);
CREATE INDEX idx_ev_results_run_name ON ev_simulation_results_final(run_name);
CREATE INDEX idx_ev_results_processing_engine ON ev_simulation_results_final(processing_engine);

-- Performance indexes for common aggregations
CREATE INDEX idx_ev_results_energy ON ev_simulation_results_final(total_energy_for_interval)
  WHERE total_energy_for_interval > 0;
CREATE INDEX idx_ev_results_power ON ev_simulation_results_final(avg_power_for_interval)
  WHERE avg_power_for_interval > 0;

-- Geographic queries
CREATE INDEX idx_ev_results_location ON ev_simulation_results_final(canton_name, province);

-- Time-based analysis
CREATE INDEX idx_ev_results_hour_index ON ev_simulation_results_final(cuarto_hora_index);
CREATE INDEX idx_ev_results_day_type ON ev_simulation_results_final(day_type, cuarto_hora_index);

-- ==============================================================================
-- CONTINUOUS AGGREGATES FOR ANALYTICS
-- ==============================================================================

-- Daily aggregates (matching original code patterns)
CREATE MATERIALIZED VIEW daily_ev_demand_summary
WITH (timescaledb.continuous) AS
SELECT 
    run_name,
    projection_type,
    canton_id,
    canton_name,
    time_bucket('1 day', quarter_hour_timestamp) AS day,
    SUM(total_energy_for_interval) AS total_energy_kwh,
    AVG(avg_power_for_interval) AS avg_power_kw,
    MAX(avg_power_for_interval) AS peak_power_kw,
    SUM(charging_events) AS total_charging_events,
    AVG(theoretical_active_vehicles) AS avg_active_vehicles,
    SUM(electricity_cost_usd) AS total_cost_usd,
    COUNT(*) AS data_points
FROM ev_simulation_results_final
GROUP BY run_name, projection_type, canton_id, canton_name, day;

-- Hourly aggregates
CREATE MATERIALIZED VIEW hourly_ev_demand_summary
WITH (timescaledb.continuous) AS
SELECT 
    run_name,
    projection_type,
    time_bucket('1 hour', quarter_hour_timestamp) AS hour,
    EXTRACT(hour FROM quarter_hour_timestamp) AS hour_of_day,
    SUM(total_energy_for_interval) AS total_energy_kwh,
    AVG(avg_power_for_interval) AS avg_power_kw,
    MAX(avg_power_for_interval) AS peak_power_kw,
    AVG(avg_temperature_c) AS avg_temperature,
    AVG(energy_efficiency_factor) AS avg_efficiency
FROM ev_simulation_results_final
GROUP BY run_name, projection_type, hour, hour_of_day;

-- Monthly aggregates by canton
CREATE MATERIALIZED VIEW monthly_canton_summary
WITH (timescaledb.continuous) AS
SELECT 
    run_name,
    projection_type,
    canton_name,
    province,
    time_bucket('1 month', quarter_hour_timestamp) AS month,
    SUM(total_energy_for_interval) AS total_energy_kwh,
    AVG(avg_power_for_interval) AS avg_power_kw,
    MAX(avg_power_for_interval) AS peak_power_kw,
    SUM(charging_events) AS total_charging_events,
    SUM(electricity_cost_usd) AS total_cost_usd
FROM ev_simulation_results_final
GROUP BY run_name, projection_type, canton_name, province, month;

-- ==============================================================================
-- COMPRESSION AND RETENTION POLICIES
-- ==============================================================================

-- Compression policy: compress chunks older than 3 days
SELECT add_compression_policy('ev_simulation_results_final', INTERVAL '3 days');

-- Refresh policies for continuous aggregates
SELECT add_continuous_aggregate_policy('daily_ev_demand_summary',
    start_offset => INTERVAL '2 days',
    end_offset => INTERVAL '1 hour',
    schedule_interval => INTERVAL '1 hour');

SELECT add_continuous_aggregate_policy('hourly_ev_demand_summary',
    start_offset => INTERVAL '1 day', 
    end_offset => INTERVAL '15 minutes',
    schedule_interval => INTERVAL '30 minutes');

SELECT add_continuous_aggregate_policy('monthly_canton_summary',
    start_offset => INTERVAL '1 month',
    end_offset => INTERVAL '1 day', 
    schedule_interval => INTERVAL '1 day');

-- ==============================================================================
-- UTILITY FUNCTIONS
-- ==============================================================================

-- Function to get simulation summary statistics
CREATE OR REPLACE FUNCTION get_simulation_summary(run_name_param TEXT DEFAULT NULL)
RETURNS TABLE(
    run_name TEXT,
    projection_type TEXT,
    total_energy_gwh NUMERIC,
    peak_demand_mw NUMERIC,
    avg_daily_energy_mwh NUMERIC,
    total_charging_events BIGINT,
    simulation_days INTEGER,
    cost_total_usd NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        r.run_name::TEXT,
        r.projection_type::TEXT,
        (SUM(r.total_energy_for_interval) / 1000000)::NUMERIC AS total_energy_gwh,
        (MAX(r.avg_power_for_interval) / 1000)::NUMERIC AS peak_demand_mw,
        (SUM(r.total_energy_for_interval) / 1000 / COUNT(DISTINCT DATE(r.quarter_hour_timestamp)))::NUMERIC AS avg_daily_energy_mwh,
        SUM(r.charging_events)::BIGINT AS total_charging_events,
        COUNT(DISTINCT DATE(r.quarter_hour_timestamp))::INTEGER AS simulation_days,
        SUM(r.electricity_cost_usd)::NUMERIC AS cost_total_usd
    FROM ev_simulation_results_final r
    WHERE (run_name_param IS NULL OR r.run_name = run_name_param)
    GROUP BY r.run_name, r.projection_type
    ORDER BY r.run_name, r.projection_type;
END;
$$ LANGUAGE plpgsql;

-- Function to get peak demand periods
CREATE OR REPLACE FUNCTION get_peak_demand_periods(
    run_name_param TEXT,
    projection_param TEXT DEFAULT 'Base',
    threshold_percentile NUMERIC DEFAULT 95
)
RETURNS TABLE(
    timestamp TIMESTAMPTZ,
    canton_name TEXT,
    power_kw NUMERIC,
    percentile_rank NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    WITH demand_percentiles AS (
        SELECT 
            percentile_cont(threshold_percentile/100.0) WITHIN GROUP (ORDER BY avg_power_for_interval) AS threshold_power
        FROM ev_simulation_results_final 
        WHERE run_name = run_name_param AND projection_type = projection_param
    )
    SELECT 
        r.quarter_hour_timestamp,
        r.canton_name::TEXT,
        r.avg_power_for_interval::NUMERIC,
        (percent_rank() OVER (ORDER BY r.avg_power_for_interval) * 100)::NUMERIC
    FROM ev_simulation_results_final r
    CROSS JOIN demand_percentiles dp
    WHERE r.run_name = run_name_param 
        AND r.projection_type = projection_param
        AND r.avg_power_for_interval >= dp.threshold_power
    ORDER BY r.avg_power_for_interval DESC, r.quarter_hour_timestamp;
END;
$$ LANGUAGE plpgsql;

-- ==============================================================================
-- VIEWS FOR COMMON QUERIES
-- ==============================================================================

-- View for latest simulation runs
CREATE VIEW latest_simulation_runs AS
SELECT DISTINCT
    run_name,
    processing_engine,
    COUNT(DISTINCT projection_type) AS scenarios_count,
    COUNT(DISTINCT canton_id) AS cantons_count, 
    MIN(quarter_hour_timestamp) AS start_timestamp,
    MAX(quarter_hour_timestamp) AS end_timestamp,
    MAX(created_at) AS last_updated
FROM ev_simulation_results_final
GROUP BY run_name, processing_engine
ORDER BY last_updated DESC;

-- View for simulation performance metrics
CREATE VIEW simulation_performance_metrics AS
SELECT 
    run_name,
    projection_type,
    processing_engine,
    COUNT(*) AS total_records,
    SUM(total_energy_for_interval) AS total_energy_kwh,
    AVG(avg_power_for_interval) AS avg_power_kw,
    MAX(avg_power_for_interval) AS peak_power_kw,
    COUNT(DISTINCT canton_id) AS cantons_simulated,
    COUNT(DISTINCT DATE(quarter_hour_timestamp)) AS days_simulated,
    (MAX(created_at) - MIN(created_at)) AS processing_duration
FROM ev_simulation_results_final
GROUP BY run_name, projection_type, processing_engine
ORDER BY run_name, projection_type;

-- ==============================================================================
-- DATA QUALITY CONSTRAINTS
-- ==============================================================================

-- Ensure reasonable timestamp ranges
ALTER TABLE ev_simulation_results_final 
ADD CONSTRAINT chk_reasonable_timestamp_range 
CHECK (quarter_hour_timestamp BETWEEN '2020-01-01' AND '2030-12-31');

-- Ensure quarter hour index is valid
ALTER TABLE ev_simulation_results_final 
ADD CONSTRAINT chk_quarter_hour_consistency
CHECK (
    cuarto_hora_index = (EXTRACT(hour FROM quarter_hour_timestamp) * 4) + 
                       (EXTRACT(minute FROM quarter_hour_timestamp) / 15) + 1
);

-- Ensure energy values are reasonable
ALTER TABLE ev_simulation_results_final 
ADD CONSTRAINT chk_reasonable_energy_values
CHECK (
    total_energy_for_interval IS NULL OR 
    (total_energy_for_interval >= 0 AND total_energy_for_interval <= 100000)
);

-- ==============================================================================
-- MONITORING AND MAINTENANCE
-- ==============================================================================

-- View for monitoring table health  
CREATE VIEW ev_simulation_table_health AS
SELECT 
    'ev_simulation_results_final' AS table_name,
    COUNT(*) AS total_rows,
    COUNT(DISTINCT run_name) AS unique_runs,
    MIN(quarter_hour_timestamp) AS earliest_timestamp,
    MAX(quarter_hour_timestamp) AS latest_timestamp,
    pg_size_pretty(pg_total_relation_size('ev_simulation_results_final')) AS table_size
FROM ev_simulation_results_final;

-- Function to clean old simulation data
CREATE OR REPLACE FUNCTION cleanup_old_simulations(days_to_keep INTEGER DEFAULT 90)
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM ev_simulation_results_final 
    WHERE created_at < NOW() - (days_to_keep || ' days')::INTERVAL;
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- ==============================================================================
-- SAMPLE DATA AND TESTING
-- ==============================================================================

-- Insert a test record to verify schema
INSERT INTO ev_simulation_results_final (
    year, month, quarter_hour_timestamp, cuarto_hora_index,
    canton_id, canton_name, province,
    projection_type, theoretical_active_vehicles, charging_events,
    total_energy_for_interval, avg_power_for_interval,
    run_name, processing_engine, batch_number
) VALUES (
    2024, 1, '2024-01-01 00:15:00+00'::TIMESTAMPTZ, 2,
    1, 'Test Canton', 'Test Province',
    'Base', 100, 25,
    150.5, 45.2,
    'SCHEMA_TEST', 'CPU', 1
);

-- Verify the insert worked
SELECT 'Schema validation successful - test record inserted' AS status,
       COUNT(*) AS test_records
FROM ev_simulation_results_final 
WHERE run_name = 'SCHEMA_TEST';

-- Clean up test record
DELETE FROM ev_simulation_results_final WHERE run_name = 'SCHEMA_TEST';

-- ==============================================================================
-- GRANTS AND PERMISSIONS (COMMENTED OUT - UNCOMMENT AS NEEDED)
-- ==============================================================================

-- Application user permissions
-- GRANT SELECT, INSERT, UPDATE, DELETE ON ev_simulation_results_final TO ev_app_user;
-- GRANT SELECT ON ALL MATERIALIZED VIEWS TO ev_app_user;
-- GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO ev_app_user;

-- Analyst read-only permissions  
-- GRANT SELECT ON ev_simulation_results_final TO ev_analyst;
-- GRANT SELECT ON ALL MATERIALIZED VIEWS TO ev_analyst;

-- ==============================================================================
-- COMPLETION MESSAGE
-- ==============================================================================

SELECT 
    'EV Simulation Database Schema (Original Code Aligned) Initialized Successfully' AS status,
    'ev_simulation_results_final' AS primary_table,
    'Ready for batch inserts from R simulation code' AS note;

COMMENT ON TABLE ev_simulation_results_final IS 
'Main table for EV simulation results - aligned with original R code that uses dbWriteTable()';

-- End of schema_original_aligned.sql