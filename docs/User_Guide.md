# User Guide

Complete user guide for the EV Demand Modeling Framework with Agent-Based Modeling and TimescaleDB integration.

## Table of Contents

1. [Getting Started](#getting-started)
2. [Basic Usage](#basic-usage)
3. [Configuration](#configuration)
4. [Working with Real Data](#working-with-real-data)
5. [Database Integration](#database-integration)
6. [Performance Optimization](#performance-optimization)
7. [Results Analysis](#results-analysis)
8. [Advanced Features](#advanced-features)
9. [Troubleshooting](#troubleshooting)

## Getting Started

### Prerequisites

Before using the framework, ensure you have:

- **R 4.0+** installed on your system
- **8GB+ RAM** recommended for medium-large simulations
- **PostgreSQL + TimescaleDB** (optional, for database features)
- **CUDA-capable GPU** (optional, for GPU acceleration)

### Installation

1. **Clone or download the project**:
   ```bash
   git clone <repository-url>
   cd ev-demand-modeling-abm-timescaledb
   ```

2. **Install R dependencies**:
   ```r
   source("requirements.R")
   ```

3. **Validate installation**:
   ```r
   source("scripts/validate_installation.R")
   ```

4. **Setup project data** (if you have access to EEQ data):
   ```r
   source("setup_project_data.R")
   ```

### Quick Start

Run your first simulation with default settings:

```r
# Load the main simulation module
source("src/ev_simulator_final.R")

# Get default configuration
config <- get_default_config()

# Run simulation
results <- run_final_simulation(
  config = config,
  processing_engine = "AUTO",
  save_to_db = FALSE,
  verbose = TRUE
)

# Check results
summary(results$summary)
```

## Basic Usage

### Running Simple Simulations

#### Small Test Simulation (Fast)

```r
source("src/ev_simulator_final.R")

# Configure for quick test
config <- get_default_config()
config$vehicles$num_vehicles <- 100      # Small fleet
config$simulation$days <- 1              # Single day
config$simulation$monte_carlo_runs <- 10 # Few iterations

# Run simulation
results <- run_final_simulation(config = config, verbose = TRUE)

# Quick analysis
cat(sprintf("Peak demand: %.2f kW\n", results$summary$peak_demand))
cat(sprintf("Average demand: %.2f kW\n", results$summary$mean_daily_demand))
```

#### Medium Simulation (Realistic)

```r
# Configure for realistic scenario
config <- get_default_config()
config$vehicles$num_vehicles <- 5000     # Medium fleet
config$simulation$days <- 7              # One week
config$simulation$monte_carlo_runs <- 100 # Good statistical sample

# Run with automatic processing mode selection
results <- run_final_simulation(
  config = config, 
  processing_engine = "AUTO",
  verbose = TRUE
)
```

#### Large Simulation (Research-grade)

```r
# Configure for comprehensive analysis
config <- get_default_config()
config$vehicles$num_vehicles <- 25000    # Large fleet
config$simulation$days <- 30             # One month
config$simulation$monte_carlo_runs <- 1000 # High precision

# Use GPU if available for better performance
results <- run_final_simulation(
  config = config,
  processing_engine = "GPU",  # Will fallback to CPU if no GPU
  verbose = TRUE
)
```

### Command Line Usage

For automated runs and scripting, use the bash wrapper:

```bash
# Basic simulation
bash scripts/run_simulation.sh

# Large simulation with GPU
bash scripts/run_simulation.sh --mode GPU --vehicles 50000 --days 30 --runs 1000

# Simulation with real data validation
bash scripts/run_simulation.sh --use-real-data --validate --generate-plots

# Custom configuration
bash scripts/run_simulation.sh --config configs/custom.json --output results/custom_run
```

## Configuration

### Understanding Configuration Structure

The configuration object controls all aspects of the simulation:

```r
config <- get_default_config()
str(config, max.level = 2)  # Examine structure
```

### Key Configuration Parameters

#### Vehicle Fleet Parameters

```r
# Fleet size and composition
config$vehicles$num_vehicles <- 10000

# Battery capacity distribution (kWh)
config$vehicles$battery_capacities_kwh <- c(40, 60, 80)
config$vehicles$battery_capacity_probs <- c(0.3, 0.5, 0.2)

# Charging power distribution (kW) 
config$vehicles$charging_powers_kw <- c(3.7, 7.4, 11, 22)
config$vehicles$charging_power_probs <- c(0.4, 0.3, 0.2, 0.1)

# Vehicle efficiency (km/kWh)
config$vehicles$efficiency_km_per_kwh$mean <- 7.0
config$vehicles$efficiency_km_per_kwh$sd <- 1.5
```

#### Charging Behavior Parameters

```r
# Charging location probabilities
config$charging$home_charging_probability <- 0.8   # 80% have home charging
config$charging$work_charging_probability <- 0.3   # 30% have workplace charging
config$charging$public_charging_probability <- 0.1  # 10% use public charging

# Charging timing preferences (24-hour format)
config$charging$charging_start_times$home$mean <- 19  # 7 PM
config$charging$charging_start_times$home$sd <- 2     # ±2 hours variation

config$charging$charging_start_times$work$mean <- 9   # 9 AM  
config$charging$charging_start_times$work$sd <- 1     # ±1 hour variation
```

#### Simulation Control Parameters

```r
# Simulation duration and resolution
config$simulation$days <- 30                    # Simulate 30 days
config$simulation$time_resolution_minutes <- 15  # 15-minute intervals

# Monte Carlo parameters
config$simulation$monte_carlo_runs <- 500       # 500 iterations
config$simulation$random_seed <- 42             # For reproducibility

# Start date
config$simulation$start_date <- as.Date("2024-01-01")
```

### Creating Custom Configurations

#### Save Custom Configuration

```r
# Create custom configuration
custom_config <- get_default_config()
custom_config$vehicles$num_vehicles <- 15000
custom_config$simulation$days <- 90

# Save for reuse
saveRDS(custom_config, "configs/my_custom_config.rds")

# Or as JSON
writeLines(
  jsonlite::toJSON(custom_config, pretty = TRUE, auto_unbox = TRUE),
  "configs/my_custom_config.json"
)
```

#### Load Custom Configuration

```r
# Load from RDS
config <- readRDS("configs/my_custom_config.rds")

# Load from JSON
config_json <- jsonlite::fromJSON("configs/my_custom_config.json")
config <- modifyList(get_default_config(), config_json)
```

## Working with Real Data

### Loading EEQ Consumption Data

The framework can calibrate simulations using real consumption data from EEQ (Empresa Eléctrica Quito).

#### Basic Data Loading

```r
source("src/real_data_loader.R")

# Load data from project directory (if data has been copied)
profiles <- load_eeq_consumption_profiles(
  data_path = "data/raw/eeq_profiles",
  limit_files = 100  # Start with 100 files for testing
)

# Or load from external directory
profiles <- load_eeq_consumption_profiles(
  data_path = "C:/path/to/EEQ/ConsolidadoPerfiles",
  limit_files = 50
)

# Examine loaded data
head(profiles)
cat(sprintf("Loaded %d records from %d meters\n", 
           nrow(profiles), 
           length(unique(profiles$meter_id))))
```

#### Data Quality Assessment

```r
# Check data completeness
summary(profiles)

# Identify missing values
missing_consumption <- sum(is.na(profiles$consumption_kwh))
cat(sprintf("Missing consumption values: %d (%.2f%%)\n",
           missing_consumption, 
           100 * missing_consumption / nrow(profiles)))

# Check consumption ranges
cat(sprintf("Consumption range: %.3f - %.3f kWh\n",
           min(profiles$consumption_kwh, na.rm = TRUE),
           max(profiles$consumption_kwh, na.rm = TRUE)))

# Check temporal coverage
date_range <- range(profiles$profile_date, na.rm = TRUE)
cat(sprintf("Date range: %s to %s\n", date_range[1], date_range[2]))
```

### Calibrating Simulations with Real Data

#### Automatic Calibration

```r
# Load real data
eeq_profiles <- load_eeq_consumption_profiles(
  data_path = "data/raw/eeq_profiles",
  limit_files = 200  # Use more data for better calibration
)

# Get base configuration
base_config <- get_default_config()

# Calibrate configuration with real data
calibrated_config <- calibrate_with_real_data(eeq_profiles, base_config)

# Examine calibration results
if (!is.null(calibrated_config$calibration)) {
  cal <- calibrated_config$calibration
  cat("📊 Calibration Results:\n")
  cat(sprintf("   Estimated vehicles: %d\n", calibrated_config$vehicles$num_vehicles))
  cat(sprintf("   Average daily consumption: %.2f kWh\n", cal$avg_daily_consumption_kwh))
  cat(sprintf("   Peak hour: %02d:00\n", cal$peak_hour))
  cat(sprintf("   Scaling factor: %.3f\n", cal$scaling_factor))
}
```

#### Manual Calibration Adjustments

```r
# Fine-tune calibrated configuration
calibrated_config$vehicles$num_vehicles <- 20000  # Adjust fleet size
calibrated_config$charging$home_charging_probability <- 0.85  # Higher home charging

# Adjust charging timing based on observed patterns
calibrated_config$charging$charging_start_times$home$mean <- 20  # 8 PM peak
calibrated_config$charging$charging_start_times$home$sd <- 1.5   # Less variation
```

### Running Calibrated Simulations

```r
# Execute simulation with calibrated configuration
results <- run_final_simulation(
  config = calibrated_config,
  processing_engine = "AUTO",
  save_to_db = FALSE,
  verbose = TRUE
)

# Validate results against real data
validation_metrics <- validate_simulation_against_real_data(
  results, 
  eeq_profiles
)

# Display validation metrics
cat("🔍 Validation Results:\n")
cat(sprintf("   Mean Absolute Error: %.3f kW\n", validation_metrics$mae))
cat(sprintf("   RMSE: %.3f kW\n", validation_metrics$rmse))
cat(sprintf("   MAPE: %.2f%%\n", validation_metrics$mape))
cat(sprintf("   Correlation: %.3f\n", validation_metrics$correlation))

# Check if validation is acceptable
if (validation_metrics$mape < 15 && validation_metrics$correlation > 0.7) {
  cat("✅ Validation passed - good calibration quality\n")
} else {
  cat("⚠️ Consider improving calibration or using more data\n")
}
```

## Database Integration

### Setting up TimescaleDB

#### Installation (Ubuntu/Debian)

```bash
# Add repositories
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -

echo "deb https://packagecloud.io/timescale/timescaledb/ubuntu/ $(lsb_release -c -s) main" | sudo tee /etc/apt/sources.list.d/timescaledb.list
wget --quiet -O - https://packagecloud.io/timescale/timescaledb/gpgkey | sudo apt-key add -

# Install packages
sudo apt update
sudo apt install postgresql-14 timescaledb-2-postgresql-14

# Configure and start
sudo timescaledb-tune --quiet --yes
sudo systemctl restart postgresql
```

#### Database Setup

```sql
-- Connect as postgres user
sudo -u postgres psql

-- Create database and user
CREATE DATABASE ev_simulation_db;
CREATE USER ev_user WITH PASSWORD 'your_secure_password';
GRANT ALL PRIVILEGES ON DATABASE ev_simulation_db TO ev_user;

-- Connect to new database
\c ev_simulation_db

-- Enable TimescaleDB
CREATE EXTENSION IF NOT EXISTS timescaledb;
GRANT ALL ON SCHEMA public TO ev_user;
```

#### Load Database Schema

```bash
# Load the database schema
psql -U ev_user -d ev_simulation_db -f database/schema.sql

# Load sample data (optional)
psql -U ev_user -d ev_simulation_db -f database/sample_data.sql
```

### Using Database Features

#### Running Simulations with Database Storage

```r
# Configure database connection in your script
config$database <- list(
  host = "localhost",
  port = 5432,
  dbname = "ev_simulation_db", 
  user = "ev_user",
  password = "your_secure_password"
)

# Run simulation with database saving enabled
results <- run_final_simulation(
  config = config,
  processing_engine = "AUTO",
  save_to_db = TRUE,  # Enable database storage
  verbose = TRUE
)
```

#### Querying Historical Results

```r
library(DBI)
library(RPostgres)

# Create connection
con <- dbConnect(
  RPostgres::Postgres(),
  host = "localhost",
  port = 5432,
  dbname = "ev_simulation_db",
  user = "ev_user", 
  password = "your_secure_password"
)

# Query simulation metadata
simulations <- dbGetQuery(con, "
  SELECT simulation_id, n_vehicles, n_days, peak_demand, load_factor, created_date
  FROM simulation_metadata 
  WHERE created_date >= CURRENT_DATE - INTERVAL '30 days'
  ORDER BY created_date DESC
  LIMIT 10
")

# Query time-series data for specific simulation
sim_id <- simulations$simulation_id[1]
timeseries <- dbGetQuery(con, sprintf("
  SELECT timestamp, total_demand, individual_demands
  FROM ev_demand_timeseries 
  WHERE simulation_id = '%s'
  ORDER BY timestamp
  LIMIT 1000
", sim_id))

# Clean up
dbDisconnect(con)
```

#### Advanced Database Queries

```sql
-- Aggregate demand by hour across all simulations
SELECT 
  EXTRACT(hour FROM timestamp) as hour_of_day,
  AVG(total_demand) as avg_demand,
  MAX(total_demand) as peak_demand,
  COUNT(*) as data_points
FROM ev_demand_timeseries 
WHERE timestamp >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY hour_of_day
ORDER BY hour_of_day;

-- Compare simulation results by fleet size
SELECT 
  sm.n_vehicles,
  AVG(sm.peak_demand) as avg_peak_demand,
  AVG(sm.load_factor) as avg_load_factor,
  COUNT(*) as num_simulations
FROM simulation_metadata sm
WHERE sm.created_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY sm.n_vehicles
ORDER BY sm.n_vehicles;

-- Time-series aggregation using TimescaleDB functions
SELECT 
  time_bucket('1 hour', timestamp) AS hour,
  simulation_id,
  AVG(total_demand) as avg_hourly_demand
FROM ev_demand_timeseries
WHERE timestamp >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
GROUP BY hour, simulation_id
ORDER BY hour, simulation_id;
```

## Performance Optimization

### Choosing Processing Modes

#### Automatic Mode Selection (Recommended)

```r
# Let the framework choose the best processing mode
results <- run_final_simulation(
  config = config,
  processing_engine = "AUTO",  # Automatically selects CPU or GPU
  verbose = TRUE
)
```

#### CPU Optimization

```r
# Configure parallel processing for CPU mode
config$monte_carlo$use_parallel <- TRUE
config$monte_carlo$chunk_size <- 100  # Process 100 vehicles per chunk

# Force CPU mode
results <- run_final_simulation(
  config = config,
  processing_engine = "CPU",
  verbose = TRUE
)
```

#### GPU Acceleration

```r
# Check GPU availability first
source("src/gpu_acceleration.R")
gpu_info <- setup_gpu_environment()

if (gpu_info$gpu_available) {
  cat(sprintf("✅ GPU available: %d GB memory\n", gpu_info$gpu_memory_gb))
  
  # Use GPU acceleration
  results <- run_final_simulation(
    config = config,
    processing_engine = "GPU",
    verbose = TRUE
  )
} else {
  cat("❌ No GPU available, using CPU mode\n")
  results <- run_final_simulation(config = config, processing_engine = "CPU")
}
```

### Memory Management

#### Optimizing for Limited Memory

```r
# Reduce memory usage for large simulations
config$simulation$monte_carlo_runs <- 100      # Fewer iterations
config$monte_carlo$chunk_size <- 50           # Smaller chunks
config$monte_carlo$use_parallel <- FALSE       # Disable parallel processing

# Run simulation with memory constraints
results <- run_final_simulation(
  config = config,
  processing_engine = "CPU",
  verbose = TRUE
)
```

#### Monitoring Memory Usage

```r
# Monitor memory during simulation
memory_before <- memory.size()
cat(sprintf("Memory before simulation: %.1f MB\n", memory_before))

results <- run_final_simulation(config = config, verbose = TRUE)

memory_after <- memory.size()
cat(sprintf("Memory after simulation: %.1f MB\n", memory_after))
cat(sprintf("Memory used: %.1f MB\n", memory_after - memory_before))

# Clean up if needed
gc()  # Garbage collection
```

### Simulation Size Guidelines

| Fleet Size | Days | MC Runs | Memory | CPU Time | GPU Time |
|-----------|------|---------|--------|----------|----------|
| 1,000     | 7    | 100     | ~100 MB | 2-5 min  | 30-60 sec |
| 5,000     | 30   | 500     | ~1 GB   | 30-60 min | 5-10 min |
| 25,000    | 90   | 1000    | ~5 GB   | 5-8 hours | 1-2 hours |
| 50,000    | 365  | 1000    | ~10 GB  | 24+ hours | 4-8 hours |

## Results Analysis

### Understanding Simulation Results

#### Results Structure

```r
# Results object structure
str(results, max.level = 2)

# Key components:
# - results$results: List of Monte Carlo iterations
# - results$summary: Aggregated statistics
# - results$metadata: Simulation configuration and timing
```

#### Summary Statistics

```r
summary_stats <- results$summary

# Key metrics
cat("📊 Simulation Summary:\n")
cat(sprintf("   Fleet size: %d vehicles\n", results$metadata$config$vehicles$num_vehicles))
cat(sprintf("   Simulation days: %d\n", results$metadata$config$simulation$days))
cat(sprintf("   Monte Carlo runs: %d\n", length(results$results)))

cat("\n⚡ Demand Statistics:\n")
cat(sprintf("   Peak demand: %.2f kW\n", summary_stats$peak_demand))
cat(sprintf("   Average demand: %.2f kW\n", summary_stats$mean_daily_demand))
cat(sprintf("   Minimum demand: %.2f kW\n", summary_stats$min_demand))
cat(sprintf("   Load factor: %.3f\n", summary_stats$load_factor))

cat("\n📈 Statistical Confidence:\n")
cat(sprintf("   Standard deviation: %.2f kW\n", summary_stats$demand_std))
cat(sprintf("   95%% confidence interval: %.2f - %.2f kW\n", 
           summary_stats$ci_lower, summary_stats$ci_upper))
```

#### Analyzing Individual Monte Carlo Runs

```r
# Extract data from first Monte Carlo run
mc_run_1 <- results$results[[1]]

# Time-series analysis
cat(sprintf("Time points per day: %d\n", length(mc_run_1$total_demand_adjusted) / results$metadata$config$simulation$days))

# Peak demand timing
peak_index <- which.max(mc_run_1$total_demand_adjusted)
peak_time <- peak_index %% 96  # 96 = 15-min intervals per day
peak_hour <- floor(peak_time * 15 / 60)
cat(sprintf("Peak demand occurs at hour %d (approx)\n", peak_hour))

# Daily patterns
if (results$metadata$config$simulation$days >= 7) {
  # Calculate daily peaks for weekly pattern
  intervals_per_day <- 96
  daily_peaks <- sapply(1:7, function(day) {
    day_start <- (day - 1) * intervals_per_day + 1
    day_end <- day * intervals_per_day
    max(mc_run_1$total_demand_adjusted[day_start:day_end])
  })
  
  weekdays <- c("Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday")
  for (i in 1:7) {
    cat(sprintf("%s peak: %.2f kW\n", weekdays[i], daily_peaks[i]))
  }
}
```

### Creating Visualizations

#### Basic Time Series Plot

```r
if (require(ggplot2, quietly = TRUE)) {
  library(ggplot2)
  library(dplyr)
  
  # Prepare data for plotting
  mc_data <- results$results[[1]]
  intervals_per_day <- 96
  time_points <- length(mc_data$total_demand_adjusted)
  
  plot_data <- data.frame(
    time_index = 1:time_points,
    hour_of_day = ((1:time_points - 1) %% intervals_per_day) * 15 / 60,
    day = ceiling((1:time_points) / intervals_per_day),
    demand = mc_data$total_demand_adjusted
  )
  
  # Daily pattern plot
  daily_pattern <- plot_data %>%
    group_by(hour_of_day) %>%
    summarise(
      avg_demand = mean(demand),
      max_demand = max(demand),
      min_demand = min(demand),
      .groups = 'drop'
    )
  
  p1 <- ggplot(daily_pattern, aes(x = hour_of_day)) +
    geom_line(aes(y = avg_demand), color = "blue", size = 1) +
    geom_ribbon(aes(ymin = min_demand, ymax = max_demand), alpha = 0.3) +
    labs(
      title = "Daily EV Charging Demand Pattern",
      x = "Hour of Day",
      y = "Demand (kW)",
      subtitle = sprintf("Fleet: %d vehicles, Days: %d", 
                        results$metadata$config$vehicles$num_vehicles,
                        results$metadata$config$simulation$days)
    ) +
    theme_minimal()
  
  print(p1)
  
  # Save plot
  ggsave("daily_demand_pattern.png", p1, width = 12, height = 8, dpi = 300)
  cat("📊 Plot saved: daily_demand_pattern.png\n")
}
```

#### Comparing Monte Carlo Runs

```r
if (require(ggplot2, quietly = TRUE) && length(results$results) >= 5) {
  library(tidyr)
  
  # Extract data from multiple MC runs
  mc_comparison <- data.frame()
  
  for (i in 1:min(5, length(results$results))) {
    run_data <- data.frame(
      time_index = 1:length(results$results[[i]]$total_demand_adjusted),
      demand = results$results[[i]]$total_demand_adjusted,
      run = paste("Run", i)
    )
    mc_comparison <- rbind(mc_comparison, run_data)
  }
  
  # Convert to hourly for clearer visualization
  hourly_data <- mc_comparison %>%
    mutate(hour = ceiling(time_index / 4)) %>%  # 4 intervals per hour
    group_by(run, hour) %>%
    summarise(avg_demand = mean(demand), .groups = 'drop')
  
  p2 <- ggplot(hourly_data, aes(x = hour, y = avg_demand, color = run)) +
    geom_line(alpha = 0.7) +
    labs(
      title = "Monte Carlo Run Comparison",
      x = "Hour",
      y = "Average Demand (kW)",
      color = "MC Run"
    ) +
    theme_minimal() +
    theme(legend.position = "bottom")
  
  print(p2)
  ggsave("monte_carlo_comparison.png", p2, width = 12, height = 8, dpi = 300)
}
```

### Exporting Results

#### Save Results in Multiple Formats

```r
# Create timestamped output directory
timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
output_dir <- file.path("results", paste0("simulation_", timestamp))
dir.create(output_dir, recursive = TRUE)

# Save complete results as RDS (R binary format)
saveRDS(results, file.path(output_dir, "complete_results.rds"))

# Save summary as CSV
summary_df <- data.frame(
  metric = c("peak_demand", "mean_demand", "min_demand", "load_factor", "std_deviation"),
  value = c(
    results$summary$peak_demand,
    results$summary$mean_daily_demand,
    results$summary$min_demand,
    results$summary$load_factor,
    results$summary$demand_std
  ),
  unit = c("kW", "kW", "kW", "ratio", "kW")
)
write.csv(summary_df, file.path(output_dir, "summary_statistics.csv"), row.names = FALSE)

# Save time-series data (first MC run)
timeseries_df <- data.frame(
  time_index = 1:length(results$results[[1]]$total_demand_adjusted),
  timestamp = seq(
    from = as.POSIXct("2024-01-01 00:00:00"),
    length.out = length(results$results[[1]]$total_demand_adjusted),
    by = "15 min"
  ),
  demand_kw = results$results[[1]]$total_demand_adjusted,
  individual_demands = results$results[[1]]$individual_demand
)
write.csv(timeseries_df, file.path(output_dir, "timeseries_data.csv"), row.names = FALSE)

# Save configuration as JSON
config_json <- jsonlite::toJSON(results$metadata$config, pretty = TRUE, auto_unbox = TRUE)
writeLines(config_json, file.path(output_dir, "simulation_config.json"))

cat(sprintf("📁 Results saved to: %s\n", output_dir))
cat("📄 Files created:\n")
cat("   - complete_results.rds (full R object)\n")
cat("   - summary_statistics.csv (summary metrics)\n")
cat("   - timeseries_data.csv (time-series demand data)\n") 
cat("   - simulation_config.json (configuration used)\n")
```

#### Generate Analysis Report

```r
# Create automated analysis report
report_content <- sprintf("
# EV Demand Simulation Report
Generated: %s

## Simulation Configuration
- Fleet Size: %d vehicles
- Simulation Period: %d days
- Monte Carlo Runs: %d
- Processing Mode: %s
- Execution Time: %.2f minutes

## Key Results
- **Peak Demand**: %.2f kW
- **Average Demand**: %.2f kW
- **Load Factor**: %.3f
- **Demand Variability**: %.2f kW (std dev)

## Statistical Confidence
- 95%% Confidence Interval: %.2f - %.2f kW
- Coefficient of Variation: %.1f%%

## Validation Metrics
%s

## Notes
- Coincidence factor formula: FC = 0.222 + 0.036 × exp(-0.0003 × n)
- Time resolution: 15-minute intervals
- All timestamps in local time

## Files Generated
- complete_results.rds: Full simulation data
- summary_statistics.csv: Key metrics
- timeseries_data.csv: Demand time series
- simulation_config.json: Configuration parameters
",
  format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
  results$metadata$config$vehicles$num_vehicles,
  results$metadata$config$simulation$days,
  length(results$results),
  results$metadata$processing_mode %||% "AUTO",
  results$metadata$execution_time_minutes %||% 0,
  results$summary$peak_demand,
  results$summary$mean_daily_demand,
  results$summary$load_factor,
  results$summary$demand_std,
  results$summary$ci_lower,
  results$summary$ci_upper,
  100 * results$summary$demand_std / results$summary$mean_daily_demand,
  if (exists("validation_metrics")) {
    sprintf("- MAPE: %.2f%%\n- Correlation: %.3f\n- RMSE: %.2f kW", 
           validation_metrics$mape, validation_metrics$correlation, validation_metrics$rmse)
  } else {
    "No validation performed"
  }
)

writeLines(report_content, file.path(output_dir, "analysis_report.md"))
cat("📋 Analysis report created: analysis_report.md\n")
```

## Advanced Features

### Custom Agent Behaviors

#### Define Custom Vehicle Types

```r
# Define electric motorcycle class
create_motorcycle_agents <- function(n_motorcycles, config) {
  motorcycles <- list()
  
  for (i in 1:n_motorcycles) {
    motorcycles[[i]] <- list(
      id = paste0("MOTO_", i),
      battery_capacity_kwh = runif(1, 3, 8),      # Small batteries
      charging_power_kw = runif(1, 1, 3),         # Slow charging
      efficiency_km_per_kwh = runif(1, 10, 15),   # High efficiency
      daily_distance_km = runif(1, 20, 60),       # Urban commuting
      home_charging_prob = 0.9,                   # High home charging
      work_charging_prob = 0.1,                   # Low workplace charging
      vehicle_type = "motorcycle"
    )
  }
  
  return(motorcycles)
}

# Integrate custom agents into simulation
custom_config <- get_default_config()
custom_config$vehicles$num_vehicles <- 800  # Regular cars
motorcycle_agents <- create_motorcycle_agents(200, custom_config)  # 200 motorcycles

# Combine agent types (would need to modify simulation engine)
```

#### Custom Charging Strategies

```r
# Define smart charging strategy
smart_charging_strategy <- function(agent, current_time, grid_load) {
  # Only charge during off-peak hours (midnight to 6 AM)
  hour <- (current_time - 1) * 15 / 60  # Convert to hours
  
  if (hour >= 0 && hour <= 6) {
    # Charge at full power during off-peak
    return(agent$charging_power_kw)
  } else if (agent$soc < 0.2) {
    # Emergency charging if SOC too low
    return(agent$charging_power_kw * 0.5)
  } else {
    # No charging during peak hours
    return(0)
  }
}

# Integrate into configuration
custom_config$charging$strategy <- "smart_charging"
custom_config$charging$strategy_function <- smart_charging_strategy
```

### Advanced Analysis Techniques

#### Sensitivity Analysis

```r
# Test sensitivity to fleet size
fleet_sizes <- c(1000, 5000, 10000, 25000, 50000)
sensitivity_results <- list()

for (i in seq_along(fleet_sizes)) {
  cat(sprintf("Testing fleet size: %d vehicles\n", fleet_sizes[i]))
  
  config_test <- get_default_config()
  config_test$vehicles$num_vehicles <- fleet_sizes[i]
  config_test$simulation$monte_carlo_runs <- 50  # Fewer runs for speed
  
  result <- run_final_simulation(config_test, verbose = FALSE)
  
  sensitivity_results[[i]] <- data.frame(
    fleet_size = fleet_sizes[i],
    peak_demand = result$summary$peak_demand,
    load_factor = result$summary$load_factor,
    per_vehicle_peak = result$summary$peak_demand / fleet_sizes[i]
  )
}

sensitivity_df <- do.call(rbind, sensitivity_results)
print(sensitivity_df)

# Plot sensitivity
if (require(ggplot2, quietly = TRUE)) {
  p_sens <- ggplot(sensitivity_df, aes(x = fleet_size)) +
    geom_line(aes(y = per_vehicle_peak), color = "blue") +
    geom_point(aes(y = per_vehicle_peak), color = "blue", size = 3) +
    labs(
      title = "Peak Demand per Vehicle vs Fleet Size",
      x = "Fleet Size",
      y = "Peak Demand per Vehicle (kW)",
      subtitle = "Shows impact of coincidence factor"
    ) +
    theme_minimal()
  
  print(p_sens)
}
```

#### Grid Impact Assessment

```r
# Assess impact on distribution transformer
assess_transformer_impact <- function(results, transformer_capacity_kva = 500) {
  
  peak_demand_kw <- results$summary$peak_demand
  
  # Convert kVA to kW (assuming 0.95 power factor)
  transformer_capacity_kw <- transformer_capacity_kva * 0.95
  
  # Calculate loading
  loading_ratio <- peak_demand_kw / transformer_capacity_kw
  
  cat("🔌 Transformer Impact Assessment:\n")
  cat(sprintf("   Transformer Capacity: %.0f kVA (%.0f kW)\n", 
             transformer_capacity_kva, transformer_capacity_kw))
  cat(sprintf("   EV Peak Demand: %.2f kW\n", peak_demand_kw))
  cat(sprintf("   Loading Ratio: %.2f (%.1f%%)\n", loading_ratio, loading_ratio * 100))
  
  if (loading_ratio > 1.0) {
    cat("   ⚠️ WARNING: Transformer overload risk!\n")
  } else if (loading_ratio > 0.8) {
    cat("   🟡 CAUTION: High loading, monitor closely\n") 
  } else {
    cat("   ✅ SAFE: Loading within acceptable limits\n")
  }
  
  # Calculate number of vehicles that can be safely accommodated
  safe_vehicles <- floor(results$metadata$config$vehicles$num_vehicles * 0.8 / loading_ratio)
  cat(sprintf("   Recommended max vehicles: %d\n", safe_vehicles))
  
  return(list(
    loading_ratio = loading_ratio,
    safe_vehicles = safe_vehicles,
    overloaded = loading_ratio > 1.0
  ))
}

# Run assessment
transformer_analysis <- assess_transformer_impact(results, transformer_capacity_kva = 500)
```

## Troubleshooting

### Common Issues and Solutions

#### Issue: "Out of memory" errors

**Symptoms**: R crashes or reports memory allocation errors during large simulations.

**Solutions**:
```r
# 1. Reduce simulation size
config$vehicles$num_vehicles <- 5000  # Instead of 50000
config$simulation$monte_carlo_runs <- 100  # Instead of 1000

# 2. Enable chunked processing
config$monte_carlo$chunk_size <- 50

# 3. Disable parallel processing if needed
config$monte_carlo$use_parallel <- FALSE

# 4. Force garbage collection
gc()
```

#### Issue: Very slow simulation performance

**Symptoms**: Simulations take much longer than expected.

**Solutions**:
```r
# 1. Check system resources
cat(sprintf("Available memory: %.1f MB\n", memory.size(NA)))
cat(sprintf("CPU cores: %d\n", parallel::detectCores()))

# 2. Optimize configuration
config$monte_carlo$use_parallel <- TRUE
config$monte_carlo$chunk_size <- 100

# 3. Try GPU acceleration
results <- run_final_simulation(config, processing_engine = "GPU")

# 4. Reduce statistical precision for testing
config$simulation$monte_carlo_runs <- 50
```

#### Issue: Poor validation metrics

**Symptoms**: High MAPE (>20%) or low correlation (<0.5) when validating against real data.

**Solutions**:
```r
# 1. Check data quality
profiles <- load_eeq_consumption_profiles(limit_files = 10)
summary(profiles$consumption_kwh)

# 2. Use more calibration data
profiles <- load_eeq_consumption_profiles(limit_files = NULL)  # Load all

# 3. Manual configuration adjustment
config$charging$charging_start_times$home$mean <- 20  # Adjust peak hour
config$vehicles$num_vehicles <- 15000  # Adjust fleet size

# 4. Check time alignment
# Ensure real data and simulation use same time resolution
```

#### Issue: Database connection failures

**Symptoms**: Cannot connect to TimescaleDB or save results.

**Solutions**:
```bash
# 1. Check if PostgreSQL is running
sudo systemctl status postgresql

# 2. Test connection manually
psql -U ev_user -d ev_simulation_db -h localhost

# 3. Verify permissions
-- In psql:
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO ev_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO ev_user;

# 4. Check firewall/network settings
sudo ufw status
```

#### Issue: Missing or corrupted EEQ data

**Symptoms**: Error loading real consumption profiles.

**Solutions**:
```r
# 1. Verify data path
data_path <- "C:/Users/LEGION/Maestria BigData/Trabajo Titulacion/EEQ/ConsolidadoPerfiles"
dir.exists(data_path)
list.files(data_path, pattern = "*.csv")[1:10]

# 2. Check file permissions and encoding
file.info(list.files(data_path, pattern = "*.csv", full.names = TRUE)[1])

# 3. Use fallback synthetic data
config$data$use_synthetic_fallback <- TRUE

# 4. Copy data into project
source("setup_project_data.R")
```

### Performance Tuning

#### Memory Usage Guidelines

| Configuration | RAM Usage | Recommended System |
|---------------|-----------|-------------------|
| Small (1K vehicles, 7 days, 100 MC) | 100 MB | 4 GB RAM |
| Medium (10K vehicles, 30 days, 500 MC) | 1-2 GB | 8 GB RAM |
| Large (50K vehicles, 90 days, 1000 MC) | 5-10 GB | 16+ GB RAM |

#### Processing Time Optimization

```r
# Benchmark different configurations
benchmark_configs <- function() {
  test_configs <- list(
    small = list(vehicles = 1000, days = 7, runs = 50),
    medium = list(vehicles = 5000, days = 30, runs = 100),
    large = list(vehicles = 25000, days = 90, runs = 500)
  )
  
  for (config_name in names(test_configs)) {
    tc <- test_configs[[config_name]]
    
    config <- get_default_config()
    config$vehicles$num_vehicles <- tc$vehicles
    config$simulation$days <- tc$days
    config$simulation$monte_carlo_runs <- tc$runs
    
    cat(sprintf("\n⏱️ Benchmarking %s configuration...\n", config_name))
    
    start_time <- Sys.time()
    results <- run_final_simulation(config, verbose = FALSE)
    end_time <- Sys.time()
    
    duration <- as.numeric(end_time - start_time, units = "mins")
    cat(sprintf("   Duration: %.2f minutes\n", duration))
    cat(sprintf("   Peak demand: %.2f kW\n", results$summary$peak_demand))
  }
}

# Run benchmarks
benchmark_configs()
```

### Getting Help

#### Validation Script

Always run the validation script after installation or configuration changes:

```r
source("scripts/validate_installation.R")
```

#### Log Files

Check log files for detailed error information:

```r
# Check R session logs
list.files("logs", pattern = "*.log", full.names = TRUE)

# Read recent log
log_files <- list.files("logs", pattern = "*.log", full.names = TRUE)
if (length(log_files) > 0) {
  latest_log <- log_files[which.max(file.mtime(log_files))]
  cat(readLines(latest_log, n = 50), sep = "\n")
}
```

#### Community and Support

- **Issues**: Report bugs or request features in the project repository
- **Documentation**: Check the `docs/` directory for additional resources
- **Examples**: See `examples/` directory for sample workflows
- **API Reference**: Consult `docs/API_Reference.md` for function details

For additional support, contact the research team or create an issue with:
1. Your system specifications
2. Complete error messages
3. Configuration used
4. Steps to reproduce the issue