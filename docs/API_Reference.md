# API Reference

Complete API documentation for the EV Demand Modeling Framework.

## Overview

This document provides detailed information about all functions, classes, and modules in the EV demand modeling framework. The framework is built in R and follows a modular architecture for maximum flexibility and maintainability.

## Core Modules

### ev_simulator_final.R

Main simulation engine containing the agent-based modeling core.

#### `run_final_simulation(config, processing_engine, save_to_db, verbose)`

**Description**: Executes the complete EV demand simulation with Monte Carlo iterations.

**Parameters**:
- `config` (list): Simulation configuration object
- `processing_engine` (character): Processing mode - "CPU", "GPU", or "AUTO"
- `save_to_db` (logical): Whether to save results to TimescaleDB
- `verbose` (logical): Enable detailed console output

**Returns**: List containing:
- `results`: Array of Monte Carlo simulation results
- `summary`: Aggregated statistics and metrics
- `metadata`: Simulation configuration and timing information

**Example**:
```r
config <- get_default_config()
results <- run_final_simulation(
  config = config,
  processing_engine = "AUTO",
  save_to_db = FALSE,
  verbose = TRUE
)
```

#### `get_default_config()`

**Description**: Generates default simulation configuration with calibrated parameters.

**Parameters**: None

**Returns**: List containing complete configuration structure:
- `simulation`: Basic simulation parameters
- `vehicles`: Vehicle fleet characteristics  
- `charging`: Charging behavior parameters
- `grid`: Grid infrastructure settings
- `monte_carlo`: Monte Carlo simulation settings

**Example**:
```r
config <- get_default_config()
config$vehicles$num_vehicles <- 5000
config$simulation$days <- 30
```

#### `generate_ev_agent(vehicle_id, config)`

**Description**: Creates individual EV agent with random characteristics.

**Parameters**:
- `vehicle_id` (integer): Unique identifier for the vehicle
- `config` (list): Configuration object containing vehicle parameters

**Returns**: List representing EV agent:
- `id`: Vehicle identifier
- `battery_capacity_kwh`: Battery capacity in kWh
- `charging_power_kw`: Maximum charging power in kW
- `efficiency_km_per_kwh`: Vehicle efficiency
- `daily_distance_km`: Daily travel distance
- `home_charging_prob`: Probability of home charging
- `work_charging_prob`: Probability of workplace charging

#### `simulate_charging_demand(agents, config, day)`

**Description**: Simulates charging demand for all agents over one day.

**Parameters**:
- `agents` (list): Vector of EV agent objects
- `config` (list): Simulation configuration
- `day` (integer): Day number in simulation

**Returns**: Data frame with columns:
- `time_index`: 15-minute time intervals (1-96)
- `individual_demand`: Charging demand per vehicle (kW)
- `total_demand`: Total fleet demand (kW)
- `total_demand_adjusted`: Demand with coincidence factor applied

#### `apply_coincidence_factor(demand_vector, num_vehicles)`

**Description**: Applies dynamic coincidence factor to account for diversity in charging.

**Parameters**:
- `demand_vector` (numeric): Vector of individual charging demands
- `num_vehicles` (integer): Total number of vehicles

**Returns**: Numeric vector of adjusted demands

**Formula**: `FC = 0.222 + 0.036 * exp(-0.0003 * n)`

Where n is the number of vehicles charging simultaneously.

### real_data_loader.R

Module for loading and processing real EEQ consumption data.

#### `load_eeq_consumption_profiles(data_path, pattern, limit_files)`

**Description**: Loads real consumption profiles from EEQ data files.

**Parameters**:
- `data_path` (character): Path to EEQ data directory
- `pattern` (character): File pattern to match (default: "*.csv")
- `limit_files` (integer): Maximum files to process (NULL for all)

**Returns**: Data frame with standardized consumption data:
- `meter_id`: Meter identifier
- `customer_id`: Customer identifier
- `profile_date`: Date of consumption profile
- `timestamp`: Time index within day
- `consumption_kwh`: Consumption in kWh
- `file_source`: Source filename

**Example**:
```r
# Load first 100 files from project data
profiles <- load_eeq_consumption_profiles(
  data_path = "data/raw/eeq_profiles",
  limit_files = 100
)

# Load all files from external source
profiles <- load_eeq_consumption_profiles(
  data_path = "C:/path/to/EEQ/data"
)
```

#### `calibrate_with_real_data(real_profiles, simulation_config)`

**Description**: Calibrates simulation parameters using real consumption data.

**Parameters**:
- `real_profiles` (data.frame): Real consumption profiles
- `simulation_config` (list): Base simulation configuration

**Returns**: Calibrated configuration list with updated parameters:
- Vehicle fleet size adjusted to match observed consumption
- Charging time patterns aligned with consumption peaks
- Scaling factors computed for demand matching

**Example**:
```r
config <- get_default_config()
real_data <- load_eeq_consumption_profiles(limit_files = 50)
calibrated_config <- calibrate_with_real_data(real_data, config)
```

#### `validate_simulation_against_real_data(simulation_results, real_profiles)`

**Description**: Validates simulation results against real consumption data.

**Parameters**:
- `simulation_results` (list): Results from `run_final_simulation()`
- `real_profiles` (data.frame): Real consumption profiles

**Returns**: List of validation metrics:
- `mae`: Mean Absolute Error (kW)
- `rmse`: Root Mean Square Error (kW)  
- `mape`: Mean Absolute Percentage Error (%)
- `correlation`: Pearson correlation coefficient
- `bias`: Mean bias (simulated - real)
- `data_points`: Number of points used in validation

### data_manager.R

Database connectivity and data persistence module.

#### `create_db_connection(host, port, dbname, user, password)`

**Description**: Creates connection to TimescaleDB database.

**Parameters**:
- `host` (character): Database host address
- `port` (integer): Database port (default: 5432)
- `dbname` (character): Database name
- `user` (character): Database username
- `password` (character): Database password

**Returns**: Database connection object (DBI connection)

#### `save_simulation_to_db(results, config, connection)`

**Description**: Saves simulation results to TimescaleDB hypertables.

**Parameters**:
- `results` (list): Simulation results from `run_final_simulation()`
- `config` (list): Simulation configuration
- `connection` (DBIConnection): Active database connection

**Returns**: Character simulation ID for database record

#### `load_historical_results(simulation_ids, connection)`

**Description**: Loads historical simulation results from database.

**Parameters**:
- `simulation_ids` (character): Vector of simulation IDs to load
- `connection` (DBIConnection): Active database connection

**Returns**: Data frame with historical simulation data

### gpu_acceleration.R

GPU computing module for large-scale simulations.

#### `setup_gpu_environment()`

**Description**: Initializes GPU environment and checks CUDA availability.

**Parameters**: None

**Returns**: List containing:
- `gpu_available`: Logical indicating GPU availability
- `cuda_version`: CUDA version if available
- `gpu_memory_gb`: Available GPU memory in GB

#### `run_simulation_gpu(agents, config, days)`

**Description**: Executes simulation using GPU acceleration.

**Parameters**:
- `agents` (list): Vector of EV agents
- `config` (list): Simulation configuration  
- `days` (integer): Number of simulation days

**Returns**: Same structure as CPU version but with GPU timing metadata

### parallel_processing.R

CPU parallel processing optimization module.

#### `setup_parallel_cluster(num_cores, cluster_type)`

**Description**: Creates parallel processing cluster.

**Parameters**:
- `num_cores` (integer): Number of CPU cores to use
- `cluster_type` (character): "PSOCK", "FORK", or "AUTO"

**Returns**: Cluster object for parallel processing

#### `run_simulation_parallel(agents, config, days, cluster)`

**Description**: Executes simulation using CPU parallelization.

**Parameters**:
- `agents` (list): Vector of EV agents
- `config` (list): Simulation configuration
- `days` (integer): Number of simulation days
- `cluster` (cluster): Parallel cluster object

**Returns**: Simulation results with parallel timing metadata

## Configuration Structure

### Complete Configuration Schema

```r
config <- list(
  # Basic simulation parameters
  simulation = list(
    days = 7,                        # Number of days to simulate
    time_resolution_minutes = 15,    # Time resolution (15 min intervals)
    monte_carlo_runs = 100,          # Number of Monte Carlo iterations
    random_seed = 42,                # Random seed for reproducibility
    start_date = as.Date("2024-01-01") # Simulation start date
  ),
  
  # Vehicle fleet characteristics
  vehicles = list(
    num_vehicles = 1000,             # Total number of EVs
    battery_capacities_kwh = c(40, 60, 80),    # Battery capacities (kWh)
    battery_capacity_probs = c(0.3, 0.5, 0.2), # Probability distribution
    charging_powers_kw = c(3.7, 7.4, 11, 22), # Charging powers (kW)
    charging_power_probs = c(0.4, 0.3, 0.2, 0.1), # Probability distribution
    efficiency_km_per_kwh = list(     # Vehicle efficiency by type
      mean = 7.0,
      sd = 1.0,
      min = 5.0,
      max = 10.0
    ),
    daily_distance_km = list(         # Daily travel distance
      mean = 50,
      sd = 20,
      min = 10,
      max = 200
    )
  ),
  
  # Charging behavior parameters
  charging = list(
    home_charging_probability = 0.8,   # Prob of home charging availability
    work_charging_probability = 0.3,   # Prob of workplace charging
    public_charging_probability = 0.1, # Prob of public charging
    
    # Charging start time distributions (hour of day)
    charging_start_times = list(
      home = list(mean = 19, sd = 2, min = 17, max = 23),
      work = list(mean = 9, sd = 1, min = 7, max = 11),
      public = list(mean = 14, sd = 3, min = 10, max = 20)
    ),
    
    # State of charge preferences
    soc_preferences = list(
      min_charge_threshold = 0.2,      # Minimum SOC before charging
      target_charge_level = 0.8,       # Target SOC for charging
      max_charge_level = 1.0          # Maximum SOC
    )
  ),
  
  # Grid infrastructure parameters
  grid = list(
    base_load_factor = 0.3,           # Base electrical load factor
    transformer_capacity_kva = 500,   # Transformer capacity
    voltage_level_kv = 13.2,          # Distribution voltage
    power_factor = 0.95              # Average power factor
  ),
  
  # Monte Carlo simulation settings
  monte_carlo = list(
    use_parallel = TRUE,              # Enable parallel processing
    chunk_size = 100,                 # Chunk size for parallel processing
    confidence_level = 0.95,          # Confidence interval level
    convergence_threshold = 0.01      # Convergence threshold for iterations
  )
)
```

## Error Handling

### Common Error Types

#### `SimulationError`
Thrown when simulation encounters critical errors:
```r
tryCatch({
  results <- run_final_simulation(config)
}, error = function(e) {
  if (inherits(e, "SimulationError")) {
    cat("Simulation failed:", e$message)
  }
})
```

#### `DataValidationError`
Thrown when input data fails validation:
```r
tryCatch({
  profiles <- load_eeq_consumption_profiles(invalid_path)
}, error = function(e) {
  if (inherits(e, "DataValidationError")) {
    cat("Data validation failed:", e$message)
  }
})
```

#### `ConfigurationError`
Thrown when configuration parameters are invalid:
```r
validate_config <- function(config) {
  if (config$vehicles$num_vehicles <= 0) {
    stop("Invalid number of vehicles", class = "ConfigurationError")
  }
}
```

## Performance Considerations

### Memory Usage

- **Small simulations** (1,000 vehicles, 7 days): ~100 MB RAM
- **Medium simulations** (10,000 vehicles, 30 days): ~1 GB RAM  
- **Large simulations** (50,000+ vehicles, 365 days): 5+ GB RAM

### Processing Time Estimates

**CPU Processing (8 cores)**:
- 1,000 vehicles, 7 days, 100 MC runs: ~5 minutes
- 10,000 vehicles, 30 days, 1000 MC runs: ~2 hours
- 50,000 vehicles, 365 days, 1000 MC runs: ~24 hours

**GPU Processing (CUDA-enabled)**:
- Performance improvement: 5-10x for large simulations
- Memory requirement: 2-4 GB GPU RAM for 50,000 vehicles

## Integration Examples

### Basic Simulation Workflow

```r
# 1. Load required modules
source("src/ev_simulator_final.R")
source("src/real_data_loader.R")

# 2. Get default configuration
config <- get_default_config()

# 3. Customize configuration
config$vehicles$num_vehicles <- 5000
config$simulation$days <- 30
config$simulation$monte_carlo_runs <- 500

# 4. Run simulation
results <- run_final_simulation(
  config = config,
  processing_engine = "AUTO",
  save_to_db = FALSE,
  verbose = TRUE
)

# 5. Analyze results
summary_stats <- results$summary
peak_demand <- max(results$results[[1]]$total_demand_adjusted)
avg_demand <- mean(results$results[[1]]$total_demand_adjusted)
```

### Real Data Calibration Workflow

```r
# 1. Load real consumption data
eeq_profiles <- load_eeq_consumption_profiles(
  data_path = "data/raw/eeq_profiles",
  limit_files = 100
)

# 2. Calibrate simulation configuration
base_config <- get_default_config()
calibrated_config <- calibrate_with_real_data(eeq_profiles, base_config)

# 3. Run calibrated simulation
results <- run_final_simulation(
  config = calibrated_config,
  processing_engine = "CPU",
  save_to_db = FALSE,
  verbose = TRUE
)

# 4. Validate against real data
validation_metrics <- validate_simulation_against_real_data(
  results, 
  eeq_profiles
)

# 5. Check validation quality
if (validation_metrics$mape < 10.0 && validation_metrics$correlation > 0.8) {
  cat("✅ Validation passed - simulation is well-calibrated\n")
} else {
  cat("⚠️ Validation concerns - consider recalibration\n")
}
```

### Database Integration Workflow

```r
# 1. Setup database connection
library(DBI)
library(RPostgres)

con <- create_db_connection(
  host = "localhost",
  port = 5432,
  dbname = "ev_simulation_db",
  user = "ev_user",
  password = "your_password"
)

# 2. Run simulation with database saving
results <- run_final_simulation(
  config = config,
  processing_engine = "AUTO",
  save_to_db = TRUE,
  verbose = TRUE
)

# 3. Query historical results
historical_data <- DBI::dbGetQuery(con, "
  SELECT simulation_id, timestamp, peak_demand, load_factor 
  FROM simulation_metadata 
  WHERE created_date >= CURRENT_DATE - INTERVAL '30 days'
  ORDER BY timestamp DESC
")

# 4. Close connection
DBI::dbDisconnect(con)
```

## Extending the Framework

### Adding New Vehicle Types

```r
# Define new vehicle configuration
custom_vehicle_config <- list(
  battery_capacities_kwh = c(20, 100, 150),  # Motorcycle, sedan, truck
  charging_powers_kw = c(2.3, 11, 50),       # AC slow, AC fast, DC fast
  efficiency_km_per_kwh = c(8, 6, 4),        # Higher efficiency for smaller vehicles
  daily_distance_km = c(30, 50, 100)         # Usage patterns by type
)

# Integrate into main configuration
config$vehicles <- modifyList(config$vehicles, custom_vehicle_config)
```

### Creating Custom Coincidence Factors

```r
# Define custom coincidence factor function
custom_coincidence_factor <- function(demand_vector, num_vehicles, time_of_day) {
  # Base coincidence factor
  base_fc <- 0.222 + 0.036 * exp(-0.0003 * num_vehicles)
  
  # Time-of-day adjustment (higher coincidence during peak hours)
  if (time_of_day >= 17 && time_of_day <= 21) {
    time_adjustment <- 1.2  # 20% higher during evening peak
  } else {
    time_adjustment <- 1.0
  }
  
  return(demand_vector * base_fc * time_adjustment)
}

# Use in simulation by modifying the coincidence factor function
```

### Adding New Data Sources

```r
# Template for new data loader
load_custom_data <- function(data_path, data_format = "csv") {
  # Implement custom data loading logic
  # Return standardized data frame with required columns:
  # - meter_id, timestamp, consumption_kwh, etc.
  
  if (data_format == "xml") {
    # XML parsing logic
  } else if (data_format == "json") {
    # JSON parsing logic  
  }
  
  return(standardized_data)
}

# Register new data loader
config$data_sources$custom <- list(
  loader_function = "load_custom_data",
  data_path = "path/to/custom/data",
  format = "xml"
)
```

## Troubleshooting

### Common Issues and Solutions

**Issue**: Out of memory errors during large simulations
**Solution**: 
- Reduce `monte_carlo_runs` or `num_vehicles`
- Enable chunked processing: `config$monte_carlo$chunk_size <- 50`
- Use GPU acceleration: `processing_engine = "GPU"`

**Issue**: Poor validation metrics (high MAPE, low correlation)
**Solution**:
- Check data quality: `validate_eeq_data(profiles)`  
- Increase calibration data: `limit_files = NULL`
- Adjust time alignment between simulated and real data

**Issue**: Slow simulation performance
**Solution**:
- Enable parallel processing: `config$monte_carlo$use_parallel = TRUE`
- Optimize chunk size: `config$monte_carlo$chunk_size = 100`
- Use appropriate processing engine for your hardware

For additional support, consult the project documentation or create an issue in the repository.