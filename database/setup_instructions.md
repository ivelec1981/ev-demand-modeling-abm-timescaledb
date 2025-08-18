# Complete Database Setup Instructions

This directory contains the complete database schema and automated setup scripts for the EV demand modeling simulation system with TimescaleDB.

## 📁 Files Overview

### Schema Files
- `complete_schema_with_source_tables.sql` - **RECOMMENDED** - Complete schema with all source data tables
- `schema_original_aligned.sql` - Simplified schema aligned with original code
- `schema.sql` - Academic research schema (comprehensive)

### Data Files
- `*.csv` - Source data files for all simulation inputs (9 tables)
- `sample_data.sql` - Sample data for testing

### Setup Scripts
- `setup_complete_database.R` - **MAIN SETUP SCRIPT** - Automated complete setup
- `load_csv_data.R` - CSV data loading with error handling and format conversion
- `setup_instructions.md` - This complete guide

## 🚀 Quick Start (Recommended)

### Prerequisites
1. **PostgreSQL 12+ with TimescaleDB installed**
2. **Database created**: `CREATE DATABASE ev_simulation_db;`
3. **R with required packages**: `DBI`, `RPostgres`, `readr`, `dplyr`, `lubridate`

### One-Command Setup
```r
# In R console:
source("database/setup_complete_database.R")
setup_database()
```

This single command will:
- ✅ Create complete schema with all tables
- ✅ Load all CSV data files automatically  
- ✅ Configure TimescaleDB hypertables
- ✅ Set up continuous aggregates and compression
- ✅ Create indexes and constraints
- ✅ Verify data completeness

## 📊 Source Data Tables

The system loads the following CSV data automatically:

| Table | CSV File | Purpose | Records |
|-------|----------|---------|---------|
| `cantones_pichincha` | cantones_pichincha.csv | Geographic regions | ~8 cantons |
| `ev_tariffs_quarter_hourly` | ev_tariffs_quarter_hourly.csv | Electricity tariffs by time | ~192 |
| `ev_models_catalog` | ev_models_catalog.csv | EV vehicle specifications | ~20 models |
| `charging_profiles` | charging_profiles..csv | Vehicle charging curves | ~1000+ profiles |
| `ev_provincial_projections` | ev_provincial_projections.csv | EV adoption projections | Variable |
| `bethania_weekly_monthly_profiles_v3` | bethania_weekly_monthly_profiles_v3.csv | Temperature profiles | ~60 |
| `battery_degradation_profiles` | battery_degradation_profiles.csv | Battery aging models | Variable |
| `ev_charging_patterns_15min` | ev_charging_patterns_15min.csv | Charging probability patterns | ~672 |
| `ev_simulation_results_final` | N/A | Main results table (hypertable) | Created empty |

## ⚡ Advanced Features

The complete setup includes:

### TimescaleDB Hypertables
- `ev_simulation_results_final` configured as hypertable
- Automatic time-based partitioning (1-week chunks)
- Optimized for time-series queries

### Continuous Aggregates
- `daily_ev_demand_summary` - Daily energy summaries
- `hourly_demand_patterns` - Hourly demand patterns

### Compression & Performance
- Automatic compression after 3 days
- Specialized indexes for simulation queries
- Data validation constraints

## ✅ Verification Commands

### Check Setup Status
```r
source("database/setup_complete_database.R")
check_database_status()
```

### Manual Verification
```sql
-- Check all tables exist and have data
SELECT * FROM get_data_completeness_report();

-- Verify TimescaleDB hypertable
SELECT * FROM _timescaledb_catalog.hypertable WHERE hypertable_name = 'ev_simulation_results_final';

-- Check source data counts
SELECT 'cantones_pichincha' as table_name, COUNT(*) as records FROM cantones_pichincha
UNION ALL
SELECT 'ev_models_catalog', COUNT(*) FROM ev_models_catalog  
UNION ALL
SELECT 'ev_tariffs_quarter_hourly', COUNT(*) FROM ev_tariffs_quarter_hourly
UNION ALL
SELECT 'charging_profiles', COUNT(*) FROM charging_profiles;
```

### Test Simulation Compatibility
```sql
-- Verify all required tables exist
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN (
  'cantones_pichincha', 'ev_tariffs_quarter_hourly', 'ev_models_catalog',
  'charging_profiles', 'ev_provincial_projections', 'bethania_weekly_monthly_profiles_v3',
  'battery_degradation_profiles', 'ev_charging_patterns_15min', 'ev_simulation_results_final'
);
```

## 🐛 Troubleshooting

### Common Issues

**1. Connection Failed**
```bash
# Check PostgreSQL status
sudo systemctl status postgresql  # Linux
brew services list | grep postgres  # macOS

# Verify connection parameters
psql -h localhost -U postgres -d ev_simulation_db -c "SELECT version();"
```

**2. TimescaleDB Extension Error**
```sql
-- Check if extension exists
SELECT * FROM pg_available_extensions WHERE name = 'timescaledb';

-- Install if missing (as superuser)
CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;
```

**3. CSV Loading Errors**
- Verify file paths in `load_csv_data.R`
- Check CSV delimiter formats (`;` vs `,`)
- Ensure UTF-8 encoding
- Check file permissions

**4. Memory/Performance Issues**
```r
# Reduce batch size in loading script
# Or adjust PostgreSQL memory settings:
# shared_buffers = 256MB
# work_mem = 64MB
```

**5. Foreign Key Constraint Errors**
```sql
-- Check data consistency
SELECT vehicle_id FROM charging_profiles 
WHERE vehicle_id NOT IN (SELECT vehicle_model_id FROM ev_models_catalog);

-- Fix by loading tables in correct order (done automatically)
```

### Force Recreate Database
```r
# If you need to start completely fresh:
source("database/setup_complete_database.R")
setup_database(force_recreate = TRUE)
```

## 🌍 Environment Configuration

### Option 1: Environment Variables
```bash
export DB_HOST="localhost"
export DB_PORT="5432"
export DB_NAME="ev_simulation_db"
export DB_USER="postgres"
export DB_PASSWORD="your_password"
```

### Option 2: R Environment
```r
Sys.setenv(
  DB_HOST = "localhost",
  DB_NAME = "ev_simulation_db",
  DB_USER = "postgres",
  DB_PASSWORD = "your_password"
)
```

## 🔧 Manual Setup (Alternative)

If you prefer step-by-step setup:

### Prerequisites
- PostgreSQL 12+ (14+ recommended)
- TimescaleDB 2.8+
- Administrative access to PostgreSQL server
- Minimum 4GB RAM (8GB+ recommended for large simulations)
- 10GB+ disk space (varies with simulation size)

## 1. Install PostgreSQL and TimescaleDB

### Option A: Using Docker (Recommended for Development)

```bash
# Pull TimescaleDB Docker image
docker pull timescale/timescaledb:latest-pg14

# Create and run container
docker run -d --name ev-timescaledb \
  -p 5432:5432 \
  -e POSTGRES_DB=ev_simulation_db \
  -e POSTGRES_USER=ev_user \
  -e POSTGRES_PASSWORD=your_secure_password \
  -v ev_data:/var/lib/postgresql/data \
  timescale/timescaledb:latest-pg14
```

### Option B: Native Installation (Ubuntu/Debian)

```bash
# Add PostgreSQL APT repository
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -

# Add TimescaleDB repository
echo "deb https://packagecloud.io/timescale/timescaledb/ubuntu/ $(lsb_release -c -s) main" | sudo tee /etc/apt/sources.list.d/timescaledb.list
wget --quiet -O - https://packagecloud.io/timescale/timescaledb/gpgkey | sudo apt-key add -

# Update and install
sudo apt update
sudo apt install postgresql-14 timescaledb-2-postgresql-14

# Configure TimescaleDB
sudo timescaledb-tune --quiet --yes

# Restart PostgreSQL
sudo systemctl restart postgresql
```

### Option C: macOS with Homebrew

```bash
# Install PostgreSQL
brew install postgresql@14

# Install TimescaleDB
brew install timescaledb

# Initialize and start PostgreSQL
brew services start postgresql@14

# Configure TimescaleDB
timescaledb-tune --quiet --yes
```

### Option D: Windows

1. Download and install PostgreSQL from https://www.postgresql.org/download/windows/
2. Download TimescaleDB installer from https://timescale.com/download
3. Run TimescaleDB installer and follow the setup wizard
4. Use `timescaledb-tune` to optimize configuration

## 2. Create Database and User

```sql
-- Connect as postgres superuser
psql -U postgres

-- Create database
CREATE DATABASE ev_simulation_db;

-- Create application user
CREATE USER ev_user WITH PASSWORD 'your_secure_password';

-- Grant permissions
GRANT ALL PRIVILEGES ON DATABASE ev_simulation_db TO ev_user;

-- Connect to the new database
\c ev_simulation_db

-- Enable TimescaleDB extension
CREATE EXTENSION IF NOT EXISTS timescaledb;

-- Grant schema permissions
GRANT ALL ON SCHEMA public TO ev_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO ev_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO ev_user;

-- Exit psql
\q
```

## 3. Load Schema and Sample Data

```bash
# Load the database schema
psql -U ev_user -d ev_simulation_db -f database/schema.sql

# Load sample data (optional)
psql -U ev_user -d ev_simulation_db -f database/sample_data.sql
```

## 4. Configuration and Optimization

### PostgreSQL Configuration (`postgresql.conf`)

```ini
# Memory Settings
shared_buffers = 256MB                    # 25% of available RAM
effective_cache_size = 1GB               # 75% of available RAM
work_mem = 64MB                          # For sorting and hash operations
maintenance_work_mem = 256MB             # For VACUUM, CREATE INDEX, etc.

# TimescaleDB Settings
shared_preload_libraries = 'timescaledb'
timescaledb.max_background_workers = 8

# Connection Settings
max_connections = 100
listen_addresses = '*'                   # Change for production security

# Write-Ahead Logging
wal_level = replica
max_wal_size = 2GB
min_wal_size = 512MB
checkpoint_completion_target = 0.9

# Query Performance
random_page_cost = 1.1                   # SSD optimization
effective_io_concurrency = 200          # SSD optimization
```

### Client Authentication (`pg_hba.conf`)

```
# TYPE  DATABASE        USER            ADDRESS                 METHOD
local   ev_simulation_db    ev_user                                md5
host    ev_simulation_db    ev_user         127.0.0.1/32           md5
host    ev_simulation_db    ev_user         ::1/128                md5

# For remote connections (adjust IP ranges as needed)
host    ev_simulation_db    ev_user         10.0.0.0/8             md5
```

## 5. Verification and Testing

### Check Installation

```sql
-- Connect to database
psql -U ev_user -d ev_simulation_db

-- Verify TimescaleDB version
SELECT default_version, installed_version 
FROM pg_available_extensions 
WHERE name = 'timescaledb';

-- Check hypertables
SELECT * FROM timescaledb_information.hypertables;

-- Verify sample data (if loaded)
SELECT simulation_id, n_vehicles, status 
FROM simulation_metadata 
WHERE simulation_id LIKE 'SAMPLE_%';
```

### Performance Test Query

```sql
-- Test time-series query performance
EXPLAIN (ANALYZE, BUFFERS) 
SELECT 
    time_bucket('1 hour', timestamp) AS hour,
    AVG(total_demand) AS avg_demand,
    COUNT(*) AS data_points
FROM ev_demand_timeseries 
WHERE timestamp >= NOW() - INTERVAL '7 days'
GROUP BY hour 
ORDER BY hour;
```

## 6. Environment Configuration

### Create `.env` file (for R application)

```bash
# Database Configuration
DB_HOST=localhost
DB_PORT=5432
DB_NAME=ev_simulation_db
DB_USER=ev_user
DB_PASSWORD=your_secure_password

# Application Settings
APP_ENV=development
LOG_LEVEL=INFO
```

### R Configuration (`config.yml`)

```yaml
default:
  database:
    host: "localhost"
    port: 5432
    dbname: "ev_simulation_db"
    user: "ev_user"
    password: "your_secure_password"
    pool_size: 10
    
development:
  inherits: default
  
production:
  inherits: default
  database:
    host: !expr Sys.getenv("DB_HOST")
    user: !expr Sys.getenv("DB_USER")
    password: !expr Sys.getenv("DB_PASSWORD")
    pool_size: 20
```

## 7. Backup and Maintenance

### Automated Backup Script

```bash
#!/bin/bash
# backup_ev_db.sh

DB_NAME="ev_simulation_db"
DB_USER="ev_user"
BACKUP_DIR="/path/to/backups"
DATE=$(date +%Y%m%d_%H%M%S)

# Create backup directory
mkdir -p $BACKUP_DIR

# Full database backup
pg_dump -U $DB_USER -h localhost \
    --format=custom \
    --compress=9 \
    --file="$BACKUP_DIR/ev_simulation_backup_$DATE.sql" \
    $DB_NAME

# Schema-only backup
pg_dump -U $DB_USER -h localhost \
    --schema-only \
    --file="$BACKUP_DIR/ev_simulation_schema_$DATE.sql" \
    $DB_NAME

# Cleanup old backups (keep 30 days)
find $BACKUP_DIR -name "ev_simulation_backup_*.sql" -mtime +30 -delete

echo "Backup completed: ev_simulation_backup_$DATE.sql"
```

### Maintenance Tasks

```sql
-- Weekly maintenance queries
-- 1. Update table statistics
ANALYZE;

-- 2. Reindex if needed
REINDEX DATABASE ev_simulation_db;

-- 3. Check hypertable health
SELECT 
    hypertable_name,
    num_chunks,
    compression_status
FROM timescaledb_information.hypertables;

-- 4. Manual compression (if needed)
SELECT compress_chunk(chunk_name) 
FROM timescaledb_information.chunks 
WHERE hypertable_name = 'ev_demand_timeseries' 
  AND NOT is_compressed
  AND chunk_start_time < NOW() - INTERVAL '7 days';

-- 5. Check database size
SELECT 
    pg_size_pretty(pg_database_size('ev_simulation_db')) AS database_size,
    pg_size_pretty(pg_total_relation_size('ev_demand_timeseries')) AS timeseries_size;
```

## 8. Security Considerations

### Production Security Checklist

- [ ] Change default passwords
- [ ] Restrict network access in `pg_hba.conf`
- [ ] Enable SSL/TLS connections
- [ ] Set up proper firewall rules
- [ ] Create limited-privilege users for applications
- [ ] Enable query logging for monitoring
- [ ] Set up regular backups
- [ ] Monitor for unusual activity

### SSL Configuration

```ini
# In postgresql.conf
ssl = on
ssl_cert_file = 'server.crt'
ssl_key_file = 'server.key'
```

```
# In pg_hba.conf - require SSL
hostssl ev_simulation_db ev_user 0.0.0.0/0 md5
```

## 9. Monitoring and Alerting

### Key Metrics to Monitor

```sql
-- Database connections
SELECT count(*) FROM pg_stat_activity;

-- Long-running queries
SELECT 
    pid,
    now() - pg_stat_activity.query_start AS duration,
    query
FROM pg_stat_activity 
WHERE (now() - pg_stat_activity.query_start) > interval '5 minutes';

-- Database size growth
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
FROM pg_tables 
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC 
LIMIT 10;

-- Hypertable compression status
SELECT 
    hypertable_name,
    SUM(CASE WHEN is_compressed THEN 1 ELSE 0 END) as compressed_chunks,
    COUNT(*) as total_chunks,
    ROUND(
        100.0 * SUM(CASE WHEN is_compressed THEN 1 ELSE 0 END) / COUNT(*), 
        2
    ) as compression_ratio
FROM timescaledb_information.chunks 
GROUP BY hypertable_name;
```

## 10. Troubleshooting

### Common Issues and Solutions

#### Issue: TimescaleDB extension not found
```sql
-- Check if extension is available
SELECT * FROM pg_available_extensions WHERE name = 'timescaledb';

-- If not available, check installation
-- Ubuntu/Debian: sudo apt install timescaledb-2-postgresql-14
```

#### Issue: Permission denied for hypertable creation
```sql
-- Grant superuser temporarily (as postgres user)
ALTER USER ev_user WITH SUPERUSER;

-- After creating hypertables, remove superuser
ALTER USER ev_user WITH NOSUPERUSER;
```

#### Issue: Poor query performance
```sql
-- Check if chunks are being excluded
EXPLAIN (ANALYZE, BUFFERS) 
SELECT * FROM ev_demand_timeseries 
WHERE timestamp >= '2024-01-01';

-- Add appropriate indexes
CREATE INDEX CONCURRENTLY idx_custom 
ON ev_demand_timeseries(simulation_id, timestamp);
```

#### Issue: High memory usage
```ini
# Reduce memory settings in postgresql.conf
shared_buffers = 128MB
work_mem = 32MB
maintenance_work_mem = 128MB
```

### Log Analysis

```bash
# Find PostgreSQL log location
sudo find /var -name "postgresql*.log" 2>/dev/null

# Monitor logs in real-time
tail -f /var/log/postgresql/postgresql-14-main.log

# Search for errors
grep -i error /var/log/postgresql/postgresql-14-main.log
```

## Support and Resources

- **TimescaleDB Documentation**: https://docs.timescale.com/
- **PostgreSQL Documentation**: https://www.postgresql.org/docs/
- **Performance Tuning**: https://docs.timescale.com/timescaledb/latest/how-to-guides/configuration/
- **Best Practices**: https://docs.timescale.com/timescaledb/latest/overview/core-concepts/

### Manual Database Creation
```sql
-- Connect as postgres superuser
psql -U postgres

-- Create database and user
CREATE DATABASE ev_simulation_db;
CREATE USER ev_user WITH PASSWORD 'secure_password';
GRANT ALL PRIVILEGES ON DATABASE ev_simulation_db TO ev_user;

-- Connect to database and enable TimescaleDB
\c ev_simulation_db
CREATE EXTENSION IF NOT EXISTS timescaledb;
GRANT ALL ON SCHEMA public TO ev_user;

\q
```

### Manual Schema and Data Loading
```bash
# 1. Create schema
psql -U ev_user -d ev_simulation_db -f complete_schema_with_source_tables.sql

# 2. Load CSV data 
Rscript -e "source('load_csv_data.R'); main()"

# Or in R console:
# source("load_csv_data.R"); main()
```

## 🎯 Next Steps

After successful setup:

### 1. Verify Installation
```r
source("database/setup_complete_database.R")
check_database_status()
```

### 2. Run EV Simulation
```r
# Execute your main simulation script
source("src/EVSimulatorFinalDefinitive.R")

# Or load framework
source("ev-demand-modeling-abm-timescaledb.txt")

# Run simulation with your parameters
simulator <- EVSimulatorFinalDefinitive$new()
results <- simulator$run_simulation(
  target_year = 2025,
  n_vehicles_base = 1000,
  projection_type = "Base"
)
```

### 3. Monitor Results
```sql
-- Check simulation progress
SELECT 
  run_name,
  COUNT(*) as records,
  MIN(quarter_hour_timestamp) as start_time,
  MAX(quarter_hour_timestamp) as end_time,
  SUM(total_energy_for_interval) as total_energy_kwh
FROM ev_simulation_results_final 
GROUP BY run_name
ORDER BY start_time DESC;

-- View latest results
SELECT * FROM ev_simulation_results_final 
ORDER BY created_at DESC 
LIMIT 10;
```

### 4. Use Analytics Views
```sql
-- Daily demand summary
SELECT * FROM daily_ev_demand_summary 
WHERE day >= CURRENT_DATE - INTERVAL '7 days'
ORDER BY day DESC;

-- Hourly patterns
SELECT 
  hour_of_day,
  day_of_week,
  avg_power_kw,
  total_energy_kwh
FROM hourly_demand_patterns 
WHERE run_name = 'your_run_name'
ORDER BY day_of_week, hour_of_day;
```

## 📈 Performance Optimization

The database includes several performance features:

### Automatic Features
- **Hypertable Partitioning**: Time-based chunks (1 week)
- **Compression**: Applied after 3 days
- **Continuous Aggregates**: Pre-computed summaries
- **Specialized Indexes**: Optimized for simulation queries

### Manual Optimization (if needed)
```sql
-- Force compression of older data
SELECT compress_chunk(chunk_name) 
FROM timescaledb_information.chunks 
WHERE hypertable_name = 'ev_simulation_results_final' 
  AND NOT is_compressed
  AND chunk_start_time < NOW() - INTERVAL '7 days';

-- Update table statistics
ANALYZE ev_simulation_results_final;

-- Check query performance
EXPLAIN (ANALYZE, BUFFERS) 
SELECT * FROM ev_simulation_results_final 
WHERE quarter_hour_timestamp >= NOW() - INTERVAL '1 day';
```

## 📋 Data Completeness

Expected record counts after successful setup:

| Table | Expected Records | Validation Query |
|-------|-----------------|------------------|
| cantones_pichincha | 8 | `SELECT COUNT(*) FROM cantones_pichincha` |
| ev_models_catalog | ~20 | `SELECT COUNT(*) FROM ev_models_catalog` |
| ev_tariffs_quarter_hourly | 192 | `SELECT COUNT(*) FROM ev_tariffs_quarter_hourly` |
| charging_profiles | 1000+ | `SELECT COUNT(*) FROM charging_profiles` |
| ev_charging_patterns_15min | 96 | `SELECT COUNT(*) FROM ev_charging_patterns_15min` |

## 🔒 Security Notes

- Change default passwords in production
- Limit network access in `pg_hba.conf`
- Enable SSL for remote connections
- Use limited-privilege database users
- Monitor for unusual query patterns

## 📚 Additional Resources

- **TimescaleDB Documentation**: https://docs.timescale.com/
- **PostgreSQL Documentation**: https://www.postgresql.org/docs/
- **R DBI Package**: https://dbi.r-dbi.org/
- **Performance Tuning**: https://docs.timescale.com/timescaledb/latest/how-to-guides/configuration/

## 🆘 Support

For project-specific support:
1. Check this documentation first
2. Verify your setup with provided verification commands  
3. Check PostgreSQL and R logs for specific errors
4. Contact the development team or create an issue in the repository

---

**✅ SUCCESS INDICATOR**: After running `setup_database()`, you should see:
```
🎉 DATABASE SETUP COMPLETE!
✅ Schema created with all tables and indexes
✅ CSV data loaded successfully  
✅ TimescaleDB features configured
✅ Database ready for EV simulation
```