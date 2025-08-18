-- ==============================================================================
-- schema.sql - TimescaleDB Schema for EV Demand Modeling Framework
-- ==============================================================================
--
-- This script creates the complete database schema for the EV demand modeling
-- framework using TimescaleDB hypertables for efficient time-series storage.
--
-- Features:
-- - Optimized time-series storage with automatic partitioning
-- - Continuous aggregates for real-time analytics
-- - Compression policies for long-term data storage
-- - Indexes for high-performance queries
--
-- Author: Iván Sánchez-Loor, Manuel Ayala-Chauvin
-- Institution: Universidad Indoamérica - SISAu Research Group
-- ==============================================================================

-- Enable TimescaleDB extension
CREATE EXTENSION IF NOT EXISTS timescaledb;

-- Enable additional extensions for analytics
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- Drop existing tables if they exist (for clean reinstall)
DROP TABLE IF EXISTS ev_demand_timeseries CASCADE;
DROP TABLE IF EXISTS ev_agents CASCADE;
DROP TABLE IF EXISTS simulation_metadata CASCADE;
DROP TABLE IF EXISTS simulation_summary CASCADE;
DROP TABLE IF EXISTS charging_stations CASCADE;
DROP TABLE IF EXISTS grid_transformers CASCADE;
DROP TABLE IF EXISTS demand_forecasts CASCADE;

-- ==============================================================================
-- 1. SIMULATION METADATA TABLE
-- ==============================================================================
-- Stores metadata about simulation runs
CREATE TABLE simulation_metadata (
    simulation_id VARCHAR(50) PRIMARY KEY,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    config_json JSONB NOT NULL,
    processing_engine VARCHAR(20) NOT NULL CHECK (processing_engine IN ('CPU', 'GPU', 'AUTO')),
    duration_seconds NUMERIC(10,3),
    n_vehicles INTEGER NOT NULL CHECK (n_vehicles > 0),
    n_runs INTEGER NOT NULL CHECK (n_runs > 0),
    days_simulated INTEGER NOT NULL CHECK (days_simulated > 0),
    random_seed INTEGER,
    version VARCHAR(20) DEFAULT '1.0.0',
    status VARCHAR(20) DEFAULT 'completed' CHECK (status IN ('running', 'completed', 'failed', 'cancelled')),
    created_by VARCHAR(100),
    notes TEXT
);

-- Indexes for simulation metadata
CREATE INDEX idx_simulation_metadata_timestamp ON simulation_metadata(timestamp);
CREATE INDEX idx_simulation_metadata_status ON simulation_metadata(status);
CREATE INDEX idx_simulation_metadata_n_vehicles ON simulation_metadata(n_vehicles);

-- ==============================================================================
-- 2. EV AGENTS TABLE
-- ==============================================================================
-- Stores characteristics of individual EV agents
CREATE TABLE ev_agents (
    simulation_id VARCHAR(50) NOT NULL REFERENCES simulation_metadata(simulation_id) ON DELETE CASCADE,
    agent_id INTEGER NOT NULL,
    vehicle_type VARCHAR(20) NOT NULL CHECK (vehicle_type IN ('compact', 'sedan', 'suv', 'truck')),
    battery_capacity NUMERIC(5,1) NOT NULL CHECK (battery_capacity > 0),
    charging_power NUMERIC(5,1) NOT NULL CHECK (charging_power > 0),
    efficiency NUMERIC(4,1) NOT NULL CHECK (efficiency > 0),
    annual_mileage NUMERIC(8,1) NOT NULL CHECK (annual_mileage > 0),
    daily_distance NUMERIC(6,1) NOT NULL CHECK (daily_distance > 0),
    home_charging BOOLEAN NOT NULL,
    work_charging BOOLEAN NOT NULL,
    soc_start_threshold NUMERIC(3,2) NOT NULL CHECK (soc_start_threshold BETWEEN 0 AND 1),
    soc_end_threshold NUMERIC(3,2) NOT NULL CHECK (soc_end_threshold BETWEEN 0 AND 1),
    convenience_factor NUMERIC(3,2) NOT NULL CHECK (convenience_factor BETWEEN 0 AND 1),
    time_flexibility NUMERIC(3,2) NOT NULL CHECK (time_flexibility BETWEEN 0 AND 1),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    PRIMARY KEY (simulation_id, agent_id)
);

-- Indexes for agents table
CREATE INDEX idx_ev_agents_simulation_id ON ev_agents(simulation_id);
CREATE INDEX idx_ev_agents_vehicle_type ON ev_agents(vehicle_type);
CREATE INDEX idx_ev_agents_battery_capacity ON ev_agents(battery_capacity);
CREATE INDEX idx_ev_agents_charging_access ON ev_agents(home_charging, work_charging);

-- ==============================================================================
-- 3. EV DEMAND TIMESERIES TABLE (HYPERTABLE)
-- ==============================================================================
-- Main time-series table for storing quarter-hourly demand data
CREATE TABLE ev_demand_timeseries (
    simulation_id VARCHAR(50) NOT NULL REFERENCES simulation_metadata(simulation_id) ON DELETE CASCADE,
    run_id INTEGER NOT NULL,
    timestamp TIMESTAMPTZ NOT NULL,
    total_demand NUMERIC(12,3) NOT NULL CHECK (total_demand >= 0),
    raw_demand NUMERIC(12,3) NOT NULL CHECK (raw_demand >= 0),
    coincidence_factor NUMERIC(6,4) NOT NULL CHECK (coincidence_factor > 0),
    n_vehicles INTEGER NOT NULL CHECK (n_vehicles > 0),
    n_charging_vehicles INTEGER DEFAULT 0 CHECK (n_charging_vehicles >= 0),
    peak_demand_flag BOOLEAN DEFAULT FALSE,
    grid_impact_score NUMERIC(5,2) DEFAULT 0,
    
    -- Composite primary key for hypertable
    PRIMARY KEY (timestamp, simulation_id, run_id)
);

-- Convert to hypertable (partitioned by time)
SELECT create_hypertable('ev_demand_timeseries', 'timestamp', chunk_time_interval => INTERVAL '1 day');

-- Indexes for time-series queries
CREATE INDEX idx_ev_demand_simulation_id ON ev_demand_timeseries(simulation_id, timestamp);
CREATE INDEX idx_ev_demand_run_id ON ev_demand_timeseries(run_id, timestamp);
CREATE INDEX idx_ev_demand_total_demand ON ev_demand_timeseries(total_demand);
CREATE INDEX idx_ev_demand_peak_flag ON ev_demand_timeseries(peak_demand_flag) WHERE peak_demand_flag = TRUE;

-- ==============================================================================
-- 4. SIMULATION SUMMARY TABLE
-- ==============================================================================
-- Stores aggregated statistics for each simulation
CREATE TABLE simulation_summary (
    simulation_id VARCHAR(50) PRIMARY KEY REFERENCES simulation_metadata(simulation_id) ON DELETE CASCADE,
    total_runs INTEGER NOT NULL,
    mean_daily_demand NUMERIC(10,3) NOT NULL,
    peak_demand NUMERIC(10,3) NOT NULL,
    min_demand NUMERIC(10,3) NOT NULL DEFAULT 0,
    load_factor NUMERIC(5,4) NOT NULL CHECK (load_factor BETWEEN 0 AND 1),
    demand_std_dev NUMERIC(10,3),
    coincidence_factor_avg NUMERIC(6,4),
    peak_hour INTEGER CHECK (peak_hour BETWEEN 0 AND 23),
    valley_hour INTEGER CHECK (valley_hour BETWEEN 0 AND 23),
    energy_total_kwh NUMERIC(15,3),
    carbon_impact_kg NUMERIC(12,3),
    grid_stress_index NUMERIC(5,2),
    validation_mape NUMERIC(5,2), -- Mean Absolute Percentage Error
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ==============================================================================
-- 5. CHARGING STATIONS TABLE
-- ==============================================================================
-- Reference data for charging infrastructure
CREATE TABLE charging_stations (
    station_id SERIAL PRIMARY KEY,
    station_name VARCHAR(100) NOT NULL,
    location_type VARCHAR(20) NOT NULL CHECK (location_type IN ('home', 'work', 'public', 'highway')),
    latitude NUMERIC(10,8),
    longitude NUMERIC(11,8),
    charging_power_kw NUMERIC(6,1) NOT NULL CHECK (charging_power_kw > 0),
    connector_type VARCHAR(20) NOT NULL,
    availability_24h BOOLEAN DEFAULT FALSE,
    cost_per_kwh NUMERIC(6,4),
    utilization_factor NUMERIC(3,2) CHECK (utilization_factor BETWEEN 0 AND 1),
    installation_date DATE,
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'maintenance', 'decommissioned')),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Spatial index for location-based queries
CREATE INDEX idx_charging_stations_location ON charging_stations USING GIST(
    point(longitude, latitude)
);
CREATE INDEX idx_charging_stations_type ON charging_stations(location_type);
CREATE INDEX idx_charging_stations_power ON charging_stations(charging_power_kw);

-- ==============================================================================
-- 6. GRID TRANSFORMERS TABLE
-- ==============================================================================
-- Reference data for electrical grid infrastructure
CREATE TABLE grid_transformers (
    transformer_id SERIAL PRIMARY KEY,
    transformer_name VARCHAR(100) NOT NULL,
    latitude NUMERIC(10,8),
    longitude NUMERIC(11,8),
    capacity_kva NUMERIC(10,1) NOT NULL CHECK (capacity_kva > 0),
    voltage_primary INTEGER NOT NULL,
    voltage_secondary INTEGER NOT NULL,
    load_factor_baseline NUMERIC(3,2) CHECK (load_factor_baseline BETWEEN 0 AND 1),
    area_served_km2 NUMERIC(8,2),
    households_served INTEGER,
    installation_year INTEGER,
    status VARCHAR(20) DEFAULT 'operational' CHECK (status IN ('operational', 'maintenance', 'upgrade', 'retired')),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for transformer data
CREATE INDEX idx_grid_transformers_location ON grid_transformers USING GIST(
    point(longitude, latitude)
);
CREATE INDEX idx_grid_transformers_capacity ON grid_transformers(capacity_kva);

-- ==============================================================================
-- 7. DEMAND FORECASTS TABLE (HYPERTABLE)
-- ==============================================================================
-- Stores forecasted demand data for comparison with simulated results
CREATE TABLE demand_forecasts (
    forecast_id SERIAL,
    timestamp TIMESTAMPTZ NOT NULL,
    forecast_type VARCHAR(30) NOT NULL CHECK (forecast_type IN ('neural_network', 'arima', 'prophet', 'ensemble')),
    forecasted_demand NUMERIC(12,3) NOT NULL CHECK (forecasted_demand >= 0),
    confidence_interval_lower NUMERIC(12,3),
    confidence_interval_upper NUMERIC(12,3),
    model_version VARCHAR(20),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    PRIMARY KEY (timestamp, forecast_type)
);

-- Convert to hypertable
SELECT create_hypertable('demand_forecasts', 'timestamp', chunk_time_interval => INTERVAL '1 week');

-- ==============================================================================
-- CONTINUOUS AGGREGATES FOR REAL-TIME ANALYTICS
-- ==============================================================================

-- Daily demand aggregates
CREATE MATERIALIZED VIEW daily_demand_summary
WITH (timescaledb.continuous) AS
SELECT 
    simulation_id,
    run_id,
    time_bucket('1 day', timestamp) AS day,
    AVG(total_demand) AS avg_demand,
    MAX(total_demand) AS peak_demand,
    MIN(total_demand) AS min_demand,
    SUM(total_demand * 0.25) AS total_energy_kwh,  -- 15-minute intervals
    COUNT(*) AS data_points,
    AVG(coincidence_factor) AS avg_coincidence_factor
FROM ev_demand_timeseries
GROUP BY simulation_id, run_id, day;

-- Hourly demand aggregates
CREATE MATERIALIZED VIEW hourly_demand_summary  
WITH (timescaledb.continuous) AS
SELECT
    simulation_id,
    run_id, 
    time_bucket('1 hour', timestamp) AS hour,
    AVG(total_demand) AS avg_demand,
    MAX(total_demand) AS peak_demand,
    MIN(total_demand) AS min_demand,
    STDDEV(total_demand) AS demand_std_dev,
    COUNT(*) AS data_points
FROM ev_demand_timeseries
GROUP BY simulation_id, run_id, hour;

-- Weekly demand patterns
CREATE MATERIALIZED VIEW weekly_demand_patterns
WITH (timescaledb.continuous) AS
SELECT
    simulation_id,
    EXTRACT(dow FROM timestamp) AS day_of_week,
    EXTRACT(hour FROM timestamp) AS hour_of_day,
    AVG(total_demand) AS avg_demand,
    STDDEV(total_demand) AS demand_std_dev,
    COUNT(*) AS observations
FROM ev_demand_timeseries
WHERE timestamp >= NOW() - INTERVAL '30 days'
GROUP BY simulation_id, day_of_week, hour_of_day;

-- ==============================================================================
-- DATA RETENTION AND COMPRESSION POLICIES
-- ==============================================================================

-- Compression policy: compress chunks older than 7 days
SELECT add_compression_policy('ev_demand_timeseries', INTERVAL '7 days');

-- Retention policy: drop chunks older than 1 year (optional)
-- SELECT add_retention_policy('ev_demand_timeseries', INTERVAL '1 year');

-- Compression for forecasts table
SELECT add_compression_policy('demand_forecasts', INTERVAL '30 days');

-- Refresh policy for continuous aggregates
SELECT add_continuous_aggregate_policy('daily_demand_summary',
    start_offset => INTERVAL '3 days',
    end_offset => INTERVAL '1 hour',
    schedule_interval => INTERVAL '1 hour');

SELECT add_continuous_aggregate_policy('hourly_demand_summary', 
    start_offset => INTERVAL '1 day',
    end_offset => INTERVAL '15 minutes', 
    schedule_interval => INTERVAL '15 minutes');

-- ==============================================================================
-- FUNCTIONS AND STORED PROCEDURES
-- ==============================================================================

-- Function to calculate dynamic coincidence factor
CREATE OR REPLACE FUNCTION calculate_coincidence_factor(n_vehicles INTEGER)
RETURNS NUMERIC AS $$
BEGIN
    -- FC = 0.222 + 0.036 * e^(-0.0003 * n)
    RETURN 0.222 + 0.036 * EXP(-0.0003 * n_vehicles);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Function to identify peak demand periods
CREATE OR REPLACE FUNCTION identify_peak_periods(sim_id VARCHAR(50))
RETURNS TABLE(
    timestamp TIMESTAMPTZ,
    demand NUMERIC,
    is_peak BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    WITH demand_stats AS (
        SELECT 
            AVG(total_demand) AS avg_demand,
            STDDEV(total_demand) AS std_demand
        FROM ev_demand_timeseries 
        WHERE simulation_id = sim_id
    )
    SELECT 
        ts.timestamp,
        ts.total_demand,
        (ts.total_demand > (ds.avg_demand + 2 * ds.std_demand)) AS is_peak
    FROM ev_demand_timeseries ts
    CROSS JOIN demand_stats ds
    WHERE ts.simulation_id = sim_id
    ORDER BY ts.timestamp;
END;
$$ LANGUAGE plpgsql;

-- Function to calculate grid impact score
CREATE OR REPLACE FUNCTION calculate_grid_impact_score(
    demand NUMERIC,
    baseline_demand NUMERIC DEFAULT 1000
)
RETURNS NUMERIC AS $$
BEGIN
    -- Simple grid impact scoring (0-10 scale)
    RETURN LEAST(10, (demand / baseline_demand) * 5);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ==============================================================================
-- TRIGGERS FOR DATA QUALITY AND AUTOMATION
-- ==============================================================================

-- Trigger to automatically update grid impact scores
CREATE OR REPLACE FUNCTION update_grid_impact_score()
RETURNS TRIGGER AS $$
BEGIN
    NEW.grid_impact_score = calculate_grid_impact_score(NEW.total_demand);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_grid_impact_score
    BEFORE INSERT OR UPDATE ON ev_demand_timeseries
    FOR EACH ROW
    EXECUTE FUNCTION update_grid_impact_score();

-- Trigger to update simulation summary timestamps
CREATE OR REPLACE FUNCTION update_simulation_summary_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_summary_timestamp
    BEFORE UPDATE ON simulation_summary
    FOR EACH ROW
    EXECUTE FUNCTION update_simulation_summary_timestamp();

-- ==============================================================================
-- VIEWS FOR COMMON QUERIES
-- ==============================================================================

-- View for latest simulation results
CREATE VIEW latest_simulations AS
SELECT 
    sm.simulation_id,
    sm.timestamp,
    sm.n_vehicles,
    sm.n_runs,
    sm.days_simulated,
    sm.processing_engine,
    sm.duration_seconds,
    ss.mean_daily_demand,
    ss.peak_demand,
    ss.load_factor,
    sm.status
FROM simulation_metadata sm
LEFT JOIN simulation_summary ss ON sm.simulation_id = ss.simulation_id
ORDER BY sm.timestamp DESC;

-- View for agent statistics by simulation
CREATE VIEW agent_statistics AS
SELECT 
    simulation_id,
    COUNT(*) AS total_agents,
    AVG(battery_capacity) AS avg_battery_capacity,
    AVG(charging_power) AS avg_charging_power,
    AVG(daily_distance) AS avg_daily_distance,
    SUM(CASE WHEN home_charging THEN 1 ELSE 0 END)::FLOAT / COUNT(*) AS home_charging_ratio,
    SUM(CASE WHEN work_charging THEN 1 ELSE 0 END)::FLOAT / COUNT(*) AS work_charging_ratio
FROM ev_agents
GROUP BY simulation_id;

-- ==============================================================================
-- INDEXES FOR PERFORMANCE OPTIMIZATION
-- ==============================================================================

-- Additional specialized indexes for common query patterns

-- Index for time-range queries with simulation filtering
CREATE INDEX idx_demand_time_simulation ON ev_demand_timeseries(timestamp, simulation_id)
INCLUDE (total_demand, coincidence_factor);

-- Index for peak demand analysis
CREATE INDEX idx_demand_peak_analysis ON ev_demand_timeseries(simulation_id, total_demand DESC, timestamp);

-- Partial index for only peak periods
CREATE INDEX idx_demand_peaks_only ON ev_demand_timeseries(simulation_id, timestamp)
WHERE peak_demand_flag = TRUE;

-- Index for Monte Carlo run comparisons
CREATE INDEX idx_demand_run_comparison ON ev_demand_timeseries(simulation_id, run_id, timestamp);

-- ==============================================================================
-- GRANTS AND PERMISSIONS
-- ==============================================================================

-- Grant permissions to application users
-- GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO ev_app_user;
-- GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO ev_app_user;
-- GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO ev_app_user;

-- Read-only access for analysts
-- GRANT SELECT ON ALL TABLES IN SCHEMA public TO ev_analyst;
-- GRANT USAGE ON SCHEMA public TO ev_analyst;

-- ==============================================================================
-- SAMPLE DATA VALIDATION CONSTRAINTS
-- ==============================================================================

-- Add constraint to ensure timestamps are reasonable
ALTER TABLE ev_demand_timeseries 
ADD CONSTRAINT chk_reasonable_timestamp 
CHECK (timestamp BETWEEN '2020-01-01' AND '2030-12-31');

-- Add constraint to ensure coincidence factor is within expected range
ALTER TABLE ev_demand_timeseries 
ADD CONSTRAINT chk_coincidence_factor_range 
CHECK (coincidence_factor BETWEEN 0.1 AND 1.0);

-- Add constraint for simulation metadata
ALTER TABLE simulation_metadata
ADD CONSTRAINT chk_reasonable_duration
CHECK (duration_seconds IS NULL OR duration_seconds BETWEEN 0 AND 86400); -- Max 24 hours

-- ==============================================================================
-- MONITORING AND MAINTENANCE
-- ==============================================================================

-- View for monitoring hypertable health
CREATE VIEW hypertable_health AS
SELECT 
    hypertable_name,
    num_chunks,
    compression_status,
    approximate_row_count
FROM timescaledb_information.hypertables h
LEFT JOIN timescaledb_information.chunks c ON h.hypertable_name = c.hypertable_name
ORDER BY hypertable_name;

-- Function to get database statistics
CREATE OR REPLACE FUNCTION get_database_stats()
RETURNS TABLE(
    table_name TEXT,
    row_count BIGINT,
    table_size TEXT,
    index_size TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        schemaname||'.'||tablename AS table_name,
        n_tup_ins - n_tup_del AS row_count,
        pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS table_size,
        pg_size_pretty(pg_indexes_size(schemaname||'.'||tablename)) AS index_size
    FROM pg_stat_user_tables
    ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
END;
$$ LANGUAGE plpgsql;

-- ==============================================================================
-- INITIALIZATION COMPLETE
-- ==============================================================================

-- Log successful schema creation
INSERT INTO simulation_metadata (
    simulation_id, 
    timestamp, 
    config_json, 
    processing_engine, 
    n_vehicles, 
    n_runs, 
    days_simulated,
    status,
    notes
) VALUES (
    'SCHEMA_INIT_' || TO_CHAR(NOW(), 'YYYYMMDD_HH24MISS'),
    NOW(),
    '{"schema_version": "1.0", "initialization": true}'::jsonb,
    'CPU',
    0,
    0,
    0,
    'completed',
    'Database schema initialized successfully'
);

-- Display schema information
SELECT 
    'EV Demand Modeling Database Schema Initialized Successfully' AS status,
    COUNT(*) AS tables_created
FROM information_schema.tables 
WHERE table_schema = 'public' AND table_type = 'BASE TABLE';

COMMENT ON DATABASE ev_simulation_db IS 'TimescaleDB database for EV demand modeling framework - Version 1.0';

-- End of schema.sql