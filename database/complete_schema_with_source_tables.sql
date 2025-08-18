-- ==============================================================================
-- complete_schema_with_source_tables.sql - Complete Schema with Source Data Tables
-- ==============================================================================
--
-- This schema includes both the simulation results table AND all the source
-- data tables that feed the simulation with their proper structure.
--
-- Author: Iván Sánchez-Loor, Manuel Ayala-Chauvin
-- ==============================================================================

-- Enable TimescaleDB extension
CREATE EXTENSION IF NOT EXISTS timescaledb;

-- Drop existing tables if they exist
DROP TABLE IF EXISTS ev_simulation_results_final CASCADE;
DROP TABLE IF EXISTS cantones_pichincha CASCADE;
DROP TABLE IF EXISTS ev_tariffs_quarter_hourly CASCADE;
DROP TABLE IF EXISTS ev_models_catalog CASCADE;
DROP TABLE IF EXISTS charging_profiles CASCADE;
DROP TABLE IF EXISTS ev_provincial_projections CASCADE;
DROP TABLE IF EXISTS bethania_weekly_monthly_profiles_v3 CASCADE;
DROP TABLE IF EXISTS battery_degradation_profiles CASCADE;
DROP TABLE IF EXISTS ev_charging_patterns_15min CASCADE;

-- ==============================================================================
-- SOURCE DATA TABLES (FOR CSV LOADING)
-- ==============================================================================

-- 1. CANTONES TABLE
CREATE TABLE cantones_pichincha (
    canton_id INTEGER PRIMARY KEY,
    canton_name VARCHAR(100) NOT NULL,
    capital_city VARCHAR(100),
    area_km2 NUMERIC(10,2),
    population_2024 INTEGER,
    latitude NUMERIC(10,8),
    longitude NUMERIC(11,8),
    urban_percentage NUMERIC(5,2),
    income_level_index NUMERIC(4,2),
    grid_reliability_index NUMERIC(4,2),
    charging_infrastructure_score NUMERIC(4,2),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. TARIFFS TABLE
CREATE TABLE ev_tariffs_quarter_hourly (
    id SERIAL PRIMARY KEY,
    tariff_type VARCHAR(50) NOT NULL,
    day_type VARCHAR(20) NOT NULL CHECK (day_type IN ('weekday', 'weekend', 'Weekday', 'Weekend')),
    quarter_hour_index INTEGER NOT NULL CHECK (quarter_hour_index BETWEEN 0 AND 95),
    hour_of_day INTEGER NOT NULL CHECK (hour_of_day BETWEEN 0 AND 23),
    minute_of_hour INTEGER NOT NULL CHECK (minute_of_hour IN (0, 15, 30, 45)),
    interval_start_time TIME NOT NULL,
    period_name VARCHAR(50),
    tariff_usd_per_kwh NUMERIC(8,6) NOT NULL CHECK (tariff_usd_per_kwh >= 0),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(tariff_type, day_type, quarter_hour_index)
);

-- 3. EV MODELS CATALOG TABLE
CREATE TABLE ev_models_catalog (
    vehicle_model_id INTEGER PRIMARY KEY,
    manufacturer VARCHAR(100) NOT NULL,
    model_name VARCHAR(100) NOT NULL,
    model_year INTEGER,
    vehicle_class VARCHAR(50),
    battery_capacity_kwh NUMERIC(6,2) NOT NULL CHECK (battery_capacity_kwh > 0),
    battery_chemistry VARCHAR(20),
    battery_warranty_years INTEGER,
    battery_warranty_cycles INTEGER,
    max_ac_power_kw NUMERIC(6,2) NOT NULL CHECK (max_ac_power_kw > 0),
    max_dc_power_kw NUMERIC(6,2),
    charging_efficiency NUMERIC(4,3) CHECK (charging_efficiency BETWEEN 0.5 AND 1.0),
    wltp_range_km INTEGER,
    energy_consumption_kwh_100km NUMERIC(5,2),
    msrp_usd INTEGER,
    availability_start_year INTEGER NOT NULL,
    availability_end_year INTEGER,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. CHARGING PROFILES TABLE
CREATE TABLE charging_profiles (
    profile_id SERIAL PRIMARY KEY,
    vehicle_id INTEGER NOT NULL REFERENCES ev_models_catalog(vehicle_model_id),
    time_minutes INTEGER NOT NULL CHECK (time_minutes >= 0),
    soc_percentage NUMERIC(5,2) NOT NULL CHECK (soc_percentage BETWEEN 0 AND 100),
    power_kw NUMERIC(8,3) NOT NULL CHECK (power_kw >= 0),
    energy_accumulated_kwh NUMERIC(10,3) NOT NULL CHECK (energy_accumulated_kwh >= 0),
    charging_phase VARCHAR(50),
    observations TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    profile_type VARCHAR(50),
    source_profile_id INTEGER,
    scaling_factors JSONB,
    simulation_metadata JSONB,
    is_validated BOOLEAN DEFAULT TRUE,
    model_match_score NUMERIC(4,3),
    generation_timestamp TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(vehicle_id, time_minutes, soc_percentage)
);

-- 5. PROVINCIAL PROJECTIONS TABLE
CREATE TABLE ev_provincial_projections (
    id SERIAL PRIMARY KEY,
    province_name VARCHAR(100) NOT NULL,
    period_date DATE NOT NULL,
    projection_type VARCHAR(50) NOT NULL CHECK (projection_type IN ('Conservative', 'Base', 'Optimistic')),
    projection_value NUMERIC(12,2) NOT NULL CHECK (projection_value >= 0),
    methodology VARCHAR(100),
    confidence_level NUMERIC(4,2),
    data_source VARCHAR(200),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(province_name, period_date, projection_type)
);

-- 6. TEMPERATURE PROFILES TABLE
CREATE TABLE bethania_weekly_monthly_profiles_v3 (
    id SERIAL PRIMARY KEY,
    station_name VARCHAR(100) DEFAULT 'Bethania',
    month INTEGER NOT NULL CHECK (month BETWEEN 1 AND 12),
    week_of_month INTEGER CHECK (week_of_month BETWEEN 1 AND 5),
    temperature_celsius NUMERIC(5,2) NOT NULL,
    humidity_percentage NUMERIC(5,2),
    precipitation_mm NUMERIC(8,2),
    data_source VARCHAR(100),
    measurement_year INTEGER,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(month, week_of_month)
);

-- 7. BATTERY DEGRADATION TABLE
CREATE TABLE battery_degradation_profiles (
    id SERIAL PRIMARY KEY,
    battery_chemistry VARCHAR(20) NOT NULL,
    years_of_use NUMERIC(4,1) NOT NULL CHECK (years_of_use >= 0),
    cycles_accumulated INTEGER DEFAULT 0,
    degradation_factor NUMERIC(5,4) NOT NULL CHECK (degradation_factor BETWEEN 0.5 AND 1.0),
    capacity_retention_percent NUMERIC(5,2),
    temperature_impact_factor NUMERIC(4,3) DEFAULT 1.0,
    usage_intensity VARCHAR(20) DEFAULT 'normal',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(battery_chemistry, years_of_use, usage_intensity)
);

-- 8. CHARGING PATTERNS TABLE
CREATE TABLE ev_charging_patterns_15min (
    id SERIAL PRIMARY KEY,
    quarter_hour INTEGER NOT NULL CHECK (quarter_hour BETWEEN 0 AND 95),
    hour_of_day INTEGER NOT NULL CHECK (hour_of_day BETWEEN 0 AND 23),
    minute_of_hour INTEGER NOT NULL CHECK (minute_of_hour IN (0, 15, 30, 45)),
    weekday NUMERIC(5,4) NOT NULL CHECK (weekday BETWEEN 0 AND 1),
    weekend NUMERIC(5,4) NOT NULL CHECK (weekend BETWEEN 0 AND 1),
    pattern_type VARCHAR(50) DEFAULT 'residential',
    data_source VARCHAR(100),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(quarter_hour, pattern_type)
);

-- ==============================================================================
-- SIMULATION RESULTS TABLE (MAIN OUTPUT)
-- ==============================================================================

CREATE TABLE ev_simulation_results_final (
    -- Temporal dimensions
    year INTEGER NOT NULL,
    month INTEGER NOT NULL CHECK (month BETWEEN 1 AND 12),
    quarter_hour_timestamp TIMESTAMPTZ NOT NULL,
    cuarto_hora_index INTEGER NOT NULL CHECK (cuarto_hora_index BETWEEN 1 AND 96),
    
    -- Geographical dimensions  
    canton_id INTEGER REFERENCES cantones_pichincha(canton_id),
    canton_name VARCHAR(100),
    province VARCHAR(50) DEFAULT 'Pichincha',
    
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
    run_name VARCHAR(200),
    processing_engine VARCHAR(20) CHECK (processing_engine IN ('CPU', 'GPU', 'PARALLEL-CPU', 'PARALLEL-GPU')),
    batch_number INTEGER,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Composite primary key
    PRIMARY KEY (quarter_hour_timestamp, canton_id, projection_type, run_name)
);

-- Convert results table to hypertable
SELECT create_hypertable('ev_simulation_results_final', 'quarter_hour_timestamp', 
                        chunk_time_interval => INTERVAL '1 week');

-- ==============================================================================
-- INDEXES FOR PERFORMANCE
-- ==============================================================================

-- Source data indexes
CREATE INDEX idx_cantones_name ON cantones_pichincha(canton_name);
CREATE INDEX idx_tariffs_lookup ON ev_tariffs_quarter_hourly(day_type, quarter_hour_index);
CREATE INDEX idx_models_availability ON ev_models_catalog(availability_start_year, availability_end_year);
CREATE INDEX idx_charging_profiles_vehicle ON charging_profiles(vehicle_id, time_minutes);
CREATE INDEX idx_projections_lookup ON ev_provincial_projections(province_name, period_date, projection_type);
CREATE INDEX idx_temperature_month ON bethania_weekly_monthly_profiles_v3(month);
CREATE INDEX idx_degradation_lookup ON battery_degradation_profiles(battery_chemistry, years_of_use);
CREATE INDEX idx_patterns_quarter ON ev_charging_patterns_15min(quarter_hour);

-- Results table indexes
CREATE INDEX idx_ev_results_timestamp ON ev_simulation_results_final(quarter_hour_timestamp);
CREATE INDEX idx_ev_results_canton ON ev_simulation_results_final(canton_id, canton_name);
CREATE INDEX idx_ev_results_projection ON ev_simulation_results_final(projection_type);
CREATE INDEX idx_ev_results_run_name ON ev_simulation_results_final(run_name);
CREATE INDEX idx_ev_results_energy ON ev_simulation_results_final(total_energy_for_interval)
  WHERE total_energy_for_interval > 0;

-- ==============================================================================
-- CONTINUOUS AGGREGATES FOR ANALYTICS  
-- ==============================================================================

-- Daily energy aggregates
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
    SUM(electricity_cost_usd) AS total_cost_usd,
    COUNT(*) AS data_points
FROM ev_simulation_results_final
GROUP BY run_name, projection_type, canton_id, canton_name, day;

-- Hourly demand patterns
CREATE MATERIALIZED VIEW hourly_demand_patterns
WITH (timescaledb.continuous) AS
SELECT 
    run_name,
    projection_type,
    EXTRACT(hour FROM quarter_hour_timestamp) AS hour_of_day,
    EXTRACT(dow FROM quarter_hour_timestamp) AS day_of_week,
    AVG(avg_power_for_interval) AS avg_power_kw,
    MAX(avg_power_for_interval) AS peak_power_kw,
    SUM(total_energy_for_interval) AS total_energy_kwh,
    COUNT(*) AS observations
FROM ev_simulation_results_final
GROUP BY run_name, projection_type, hour_of_day, day_of_week;

-- ==============================================================================
-- COMPRESSION AND RETENTION POLICIES
-- ==============================================================================

-- Compression for results table
SELECT add_compression_policy('ev_simulation_results_final', INTERVAL '3 days');

-- Refresh policies for continuous aggregates
SELECT add_continuous_aggregate_policy('daily_ev_demand_summary',
    start_offset => INTERVAL '2 days',
    end_offset => INTERVAL '1 hour',
    schedule_interval => INTERVAL '1 hour');

SELECT add_continuous_aggregate_policy('hourly_demand_patterns',
    start_offset => INTERVAL '1 day',
    end_offset => INTERVAL '15 minutes', 
    schedule_interval => INTERVAL '30 minutes');

-- ==============================================================================
-- UTILITY FUNCTIONS
-- ==============================================================================

-- Function to get data completeness report
CREATE OR REPLACE FUNCTION get_data_completeness_report()
RETURNS TABLE(
    table_name TEXT,
    record_count BIGINT,
    last_updated TIMESTAMPTZ,
    data_status TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        'cantones_pichincha'::TEXT,
        COUNT(*)::BIGINT,
        MAX(created_at),
        CASE WHEN COUNT(*) > 0 THEN 'OK' ELSE 'EMPTY' END::TEXT
    FROM cantones_pichincha
    
    UNION ALL
    
    SELECT 
        'ev_tariffs_quarter_hourly'::TEXT,
        COUNT(*)::BIGINT,
        MAX(created_at),
        CASE WHEN COUNT(*) >= 192 THEN 'OK' ELSE 'INCOMPLETE' END::TEXT  -- 96 intervals x 2 day types
    FROM ev_tariffs_quarter_hourly
    
    UNION ALL
    
    SELECT 
        'ev_models_catalog'::TEXT,
        COUNT(*)::BIGINT,
        MAX(created_at),
        CASE WHEN COUNT(*) > 0 THEN 'OK' ELSE 'EMPTY' END::TEXT
    FROM ev_models_catalog
    
    UNION ALL
    
    SELECT 
        'charging_profiles'::TEXT,
        COUNT(*)::BIGINT,
        MAX(created_at),
        CASE WHEN COUNT(*) > 0 THEN 'OK' ELSE 'EMPTY' END::TEXT
    FROM charging_profiles
    
    UNION ALL
    
    SELECT 
        'ev_provincial_projections'::TEXT,
        COUNT(*)::BIGINT,
        MAX(created_at),
        CASE WHEN COUNT(*) > 0 THEN 'OK' ELSE 'EMPTY' END::TEXT
    FROM ev_provincial_projections
    
    UNION ALL
    
    SELECT 
        'ev_simulation_results_final'::TEXT,
        COUNT(*)::BIGINT,
        MAX(created_at),
        CASE WHEN COUNT(*) > 0 THEN 'OK' ELSE 'EMPTY' END::TEXT
    FROM ev_simulation_results_final;
END;
$$ LANGUAGE plpgsql;

-- ==============================================================================
-- VALIDATION CONSTRAINTS
-- ==============================================================================

-- Ensure data consistency
ALTER TABLE charging_profiles 
ADD CONSTRAINT chk_soc_energy_consistency 
CHECK (soc_percentage <= 100 AND energy_accumulated_kwh >= 0);

ALTER TABLE ev_tariffs_quarter_hourly
ADD CONSTRAINT chk_quarter_hour_consistency
CHECK (quarter_hour_index = (hour_of_day * 4) + (minute_of_hour / 15));

-- ==============================================================================
-- COMPLETION MESSAGE
-- ==============================================================================

SELECT 
    'Complete EV Simulation Database Schema Initialized Successfully' AS status,
    'Ready for CSV data loading' AS next_step;

COMMENT ON DATABASE ev_simulation_db IS 
'Complete EV simulation database with source tables and results table - Version 2.0';

-- End of complete_schema_with_source_tables.sql