# ==============================================================================
# ev_simulator_final.R - Main EV Demand Modeling Simulator
# ==============================================================================
#
# This is the main simulation engine for the EV demand modeling framework.
# It combines Agent-Based Modeling (ABM) with Monte Carlo simulation and
# TimescaleDB integration for quarter-hourly EV charging demand projection.
#
# Key Features:
# - Heterogeneous EV agent behavior simulation
# - Dynamic coincidence factor: FC = 0.222 + 0.036*e^(-0.0003n)
# - GPU acceleration support
# - Parallel processing capabilities
# - TimescaleDB integration
#
# Author: Iván Sánchez-Loor, Manuel Ayala-Chauvin
# Institution: Universidad Indoamérica - SISAu Research Group
# ==============================================================================

# Load required libraries
suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(purrr)
  library(lubridate)
  library(parallel)
  library(future)
  library(furrr)
  library(DBI)
  library(RPostgres)
  library(MASS)
  library(truncnorm)
  library(progressr)
})

# Source supporting modules
source("src/data_manager.R")
source("src/parallel_processing.R")

# Try to load GPU acceleration if available
gpu_available <- tryCatch({
  source("src/gpu_acceleration.R")
  TRUE
}, error = function(e) {
  message("GPU acceleration not available, using CPU processing")
  FALSE
})

#' Main EV Simulation Function
#' 
#' Runs the complete EV demand simulation with specified parameters
#' 
#' @param config List containing simulation configuration
#' @param processing_engine Character: "CPU", "GPU", or "AUTO"
#' @param save_to_db Logical: whether to save results to database
#' @param verbose Logical: whether to print progress messages
#' 
#' @return List containing simulation results and metadata
run_final_simulation <- function(config = NULL, 
                                processing_engine = "AUTO",
                                save_to_db = TRUE,
                                verbose = TRUE) {
  
  if (verbose) cat("🚀 Starting EV Demand Simulation...\n")
  
  # Set default configuration if not provided
  if (is.null(config)) {
    config <- get_default_config()
  }
  
  # Validate configuration
  config <- validate_config(config)
  
  # Initialize simulation environment
  sim_env <- initialize_simulation(config, processing_engine, verbose)
  
  # Generate EV agent population
  if (verbose) cat("👥 Generating EV agent population...\n")
  agents <- generate_ev_agents(config$vehicles, verbose)
  
  # Run Monte Carlo simulation
  if (verbose) cat("🎲 Running Monte Carlo simulation...\n")
  with_progress({
    p <- progressor(steps = config$simulation$monte_carlo_runs)
    simulation_results <- run_monte_carlo_simulation(
      agents = agents,
      config = config,
      sim_env = sim_env,
      progress_callback = p
    )
  })
  
  # Process and aggregate results
  if (verbose) cat("📊 Processing simulation results...\n")
  processed_results <- process_simulation_results(
    simulation_results, 
    config, 
    agents
  )
  
  # Calculate coincidence factors
  if (verbose) cat("🔄 Calculating dynamic coincidence factors...\n")
  final_results <- calculate_coincidence_factors(processed_results, config)
  
  # Save to database if requested
  if (save_to_db) {
    if (verbose) cat("💾 Saving results to TimescaleDB...\n")
    save_results_to_db(final_results, config)
  }
  
  # Generate summary statistics
  summary_stats <- generate_summary_statistics(final_results, config)
  
  # Cleanup
  cleanup_simulation(sim_env)
  
  if (verbose) cat("✅ Simulation completed successfully!\n")
  
  return(list(
    results = final_results,
    summary = summary_stats,
    config = config,
    agents = agents,
    metadata = list(
      simulation_id = generate_simulation_id(),
      timestamp = Sys.time(),
      processing_engine = sim_env$processing_engine,
      duration = sim_env$end_time - sim_env$start_time
    )
  ))
}

#' Get Default Configuration
#' 
#' Returns default simulation configuration parameters
#' 
#' @return List with default configuration
get_default_config <- function() {
  list(
    vehicles = list(
      num_vehicles = 10000,
      battery_sizes = c(40, 60, 80),  # kWh
      battery_size_probs = c(0.4, 0.4, 0.2),
      charging_powers = c(3.7, 7.4, 11, 22),  # kW
      charging_power_probs = c(0.3, 0.4, 0.2, 0.1),
      vehicle_types = c("compact", "sedan", "suv"),
      vehicle_type_probs = c(0.5, 0.3, 0.2),
      efficiency = c(6.0, 7.0, 8.0),  # km/kWh by type
      annual_mileage = list(
        mean = 15000,  # km/year
        sd = 5000
      )
    ),
    
    simulation = list(
      days = 30,
      time_resolution = 15,  # minutes
      start_date = as.Date("2024-01-01"),
      monte_carlo_runs = 1000,
      random_seed = 42
    ),
    
    charging = list(
      home_charging_prob = 0.8,
      work_charging_prob = 0.3,
      public_charging_prob = 0.1,
      charging_start_times = list(
        home = list(mean = 19, sd = 2),     # 7 PM ± 2 hours
        work = list(mean = 9, sd = 1),      # 9 AM ± 1 hour
        public = list(mean = 14, sd = 4)    # 2 PM ± 4 hours
      ),
      charging_durations = list(
        home = list(shape = 2, scale = 3),   # Weibull parameters
        work = list(shape = 1.5, scale = 4),
        public = list(shape = 1, scale = 2)
      )
    ),
    
    behavioral = list(
      soc_start_threshold = 0.3,  # Start charging below 30%
      soc_end_threshold = 0.9,    # Stop charging at 90%
      convenience_factor = 0.8,   # Willingness to charge
      time_flexibility = 0.6      # Schedule flexibility
    ),
    
    processing = list(
      parallel_cores = parallel::detectCores() - 1,
      memory_limit = "8GB",
      batch_size = 1000,
      gpu_enabled = FALSE
    ),
    
    output = list(
      time_aggregation = c("15min", "hourly", "daily"),
      spatial_aggregation = c("individual", "transformer", "feeder"),
      export_formats = c("db", "csv", "parquet"),
      generate_plots = TRUE
    )
  )
}

#' Validate Configuration
#' 
#' Validates and sanitizes configuration parameters
#' 
#' @param config Configuration list
#' @return Validated configuration list
validate_config <- function(config) {
  # Validate required sections
  required_sections <- c("vehicles", "simulation", "charging", "processing")
  missing_sections <- setdiff(required_sections, names(config))
  
  if (length(missing_sections) > 0) {
    stop(paste("Missing configuration sections:", paste(missing_sections, collapse = ", ")))
  }
  
  # Validate numeric ranges
  if (config$vehicles$num_vehicles < 1 || config$vehicles$num_vehicles > 1e6) {
    stop("Number of vehicles must be between 1 and 1,000,000")
  }
  
  if (config$simulation$days < 1 || config$simulation$days > 365) {
    stop("Simulation days must be between 1 and 365")
  }
  
  if (!config$simulation$time_resolution %in% c(1, 5, 15, 30, 60)) {
    stop("Time resolution must be one of: 1, 5, 15, 30, 60 minutes")
  }
  
  # Validate probability vectors
  if (abs(sum(config$vehicles$battery_size_probs) - 1) > 1e-6) {
    config$vehicles$battery_size_probs <- config$vehicles$battery_size_probs / sum(config$vehicles$battery_size_probs)
    warning("Battery size probabilities normalized to sum to 1")
  }
  
  # Set random seed for reproducibility
  if (!is.null(config$simulation$random_seed)) {
    set.seed(config$simulation$random_seed)
  }
  
  return(config)
}

#' Initialize Simulation Environment
#' 
#' Sets up the simulation environment and processing backend
#' 
#' @param config Configuration list
#' @param processing_engine Processing engine choice
#' @param verbose Verbose output flag
#' @return Simulation environment list
initialize_simulation <- function(config, processing_engine, verbose) {
  start_time <- Sys.time()
  
  # Determine optimal processing engine
  if (processing_engine == "AUTO") {
    if (gpu_available && config$vehicles$num_vehicles > 50000) {
      processing_engine <- "GPU"
    } else {
      processing_engine <- "CPU"
    }
  }
  
  # Setup parallel processing for CPU
  if (processing_engine == "CPU") {
    setup_parallel_processing(config$processing$parallel_cores, verbose)
  }
  
  # Initialize GPU if requested
  if (processing_engine == "GPU") {
    if (!gpu_available) {
      warning("GPU not available, falling back to CPU")
      processing_engine <- "CPU"
      setup_parallel_processing(config$processing$parallel_cores, verbose)
    } else {
      initialize_gpu_processing(verbose)
    }
  }
  
  if (verbose) {
    cat(sprintf("⚙️  Processing engine: %s\n", processing_engine))
    cat(sprintf("🔧 Parallel cores: %d\n", config$processing$parallel_cores))
  }
  
  return(list(
    start_time = start_time,
    processing_engine = processing_engine,
    simulation_id = generate_simulation_id()
  ))
}

#' Generate EV Agents
#' 
#' Creates heterogeneous EV agent population with realistic characteristics
#' 
#' @param vehicle_config Vehicle configuration parameters
#' @param verbose Verbose output flag
#' @return Data frame of EV agents
generate_ev_agents <- function(vehicle_config, verbose = TRUE) {
  n <- vehicle_config$num_vehicles
  
  if (verbose) cat(sprintf("   Creating %s EV agents...\n", format(n, big.mark = ",")))
  
  # Generate vehicle types
  vehicle_types <- sample(
    vehicle_config$vehicle_types,
    n,
    replace = TRUE,
    prob = vehicle_config$vehicle_type_probs
  )
  
  # Generate battery sizes
  battery_sizes <- sample(
    vehicle_config$battery_sizes,
    n,
    replace = TRUE,
    prob = vehicle_config$battery_size_probs
  )
  
  # Generate charging powers
  charging_powers <- sample(
    vehicle_config$charging_powers,
    n,
    replace = TRUE,
    prob = vehicle_config$charging_power_probs
  )
  
  # Generate efficiency based on vehicle type
  efficiency <- sapply(vehicle_types, function(type) {
    idx <- which(vehicle_config$vehicle_types == type)
    vehicle_config$efficiency[idx]
  })
  
  # Generate annual mileage with truncated normal distribution
  annual_mileage <- truncnorm::rtruncnorm(
    n,
    a = 5000,   # minimum 5,000 km/year
    b = 50000,  # maximum 50,000 km/year
    mean = vehicle_config$annual_mileage$mean,
    sd = vehicle_config$annual_mileage$sd
  )
  
  # Calculate daily travel distance
  daily_distance <- annual_mileage / 365
  
  # Generate charging preferences
  home_charging_access <- rbinom(n, 1, 0.7)  # 70% have home charging
  work_charging_access <- rbinom(n, 1, 0.4)  # 40% have work charging
  
  # Create agent data frame
  agents <- data.frame(
    agent_id = 1:n,
    vehicle_type = vehicle_types,
    battery_capacity = battery_sizes,
    charging_power = charging_powers,
    efficiency = efficiency,
    annual_mileage = annual_mileage,
    daily_distance = daily_distance,
    home_charging = as.logical(home_charging_access),
    work_charging = as.logical(work_charging_access),
    stringsAsFactors = FALSE
  )
  
  # Add behavioral parameters with some randomness
  agents$soc_start_threshold <- truncnorm::rtruncnorm(
    n, a = 0.1, b = 0.5, mean = 0.3, sd = 0.1
  )
  
  agents$soc_end_threshold <- truncnorm::rtruncnorm(
    n, a = 0.7, b = 1.0, mean = 0.9, sd = 0.05
  )
  
  agents$convenience_factor <- rbeta(n, 2, 1)  # Skewed towards convenient charging
  agents$time_flexibility <- rbeta(n, 1.5, 1.5)  # Symmetric around 0.5
  
  if (verbose) {
    cat(sprintf("   ✅ Generated %s agents\n", format(nrow(agents), big.mark = ",")))
    cat(sprintf("   📊 Home charging access: %.1f%%\n", mean(agents$home_charging) * 100))
    cat(sprintf("   📊 Work charging access: %.1f%%\n", mean(agents$work_charging) * 100))
    cat(sprintf("   📊 Average battery capacity: %.1f kWh\n", mean(agents$battery_capacity)))
  }
  
  return(agents)
}

#' Run Monte Carlo Simulation
#' 
#' Executes Monte Carlo simulation runs with parallel processing
#' 
#' @param agents EV agent data frame
#' @param config Configuration list
#' @param sim_env Simulation environment
#' @param progress_callback Progress callback function
#' @return Simulation results list
run_monte_carlo_simulation <- function(agents, config, sim_env, progress_callback = NULL) {
  n_runs <- config$simulation$monte_carlo_runs
  
  # Create simulation scenarios
  scenarios <- create_simulation_scenarios(agents, config, n_runs)
  
  # Run simulations in parallel
  if (sim_env$processing_engine == "GPU") {
    results <- run_gpu_monte_carlo(scenarios, config, progress_callback)
  } else {
    results <- future_map(scenarios, function(scenario) {
      if (!is.null(progress_callback)) progress_callback()
      simulate_single_scenario(scenario, config)
    }, .options = furrr_options(seed = TRUE))
  }
  
  return(results)
}

#' Create Simulation Scenarios
#' 
#' Creates individual scenarios for Monte Carlo simulation
#' 
#' @param agents EV agent data frame
#' @param config Configuration list
#' @param n_runs Number of Monte Carlo runs
#' @return List of simulation scenarios
create_simulation_scenarios <- function(agents, config, n_runs) {
  scenarios <- vector("list", n_runs)
  
  for (i in 1:n_runs) {
    scenarios[[i]] <- list(
      run_id = i,
      agents = agents,
      start_date = config$simulation$start_date,
      days = config$simulation$days,
      time_resolution = config$simulation$time_resolution,
      charging_config = config$charging,
      behavioral_config = config$behavioral
    )
  }
  
  return(scenarios)
}

#' Simulate Single Scenario
#' 
#' Simulates a single Monte Carlo scenario
#' 
#' @param scenario Scenario configuration
#' @param config Global configuration
#' @return Scenario results
simulate_single_scenario <- function(scenario, config) {
  # Initialize time series
  time_series <- create_time_series(
    scenario$start_date,
    scenario$days,
    scenario$time_resolution
  )
  
  # Initialize demand matrix
  demand_matrix <- matrix(
    0,
    nrow = nrow(scenario$agents),
    ncol = length(time_series)
  )
  
  # Simulate each agent
  for (agent_idx in 1:nrow(scenario$agents)) {
    agent <- scenario$agents[agent_idx, ]
    
    # Generate daily patterns
    daily_patterns <- generate_daily_patterns(
      agent,
      scenario$days,
      scenario$charging_config,
      scenario$behavioral_config
    )
    
    # Convert to time series
    agent_demand <- patterns_to_timeseries(
      daily_patterns,
      time_series,
      scenario$time_resolution
    )
    
    demand_matrix[agent_idx, ] <- agent_demand
  }
  
  # Calculate aggregated demand
  total_demand <- colSums(demand_matrix)
  
  return(list(
    run_id = scenario$run_id,
    time_series = time_series,
    total_demand = total_demand,
    individual_demand = demand_matrix,
    agents = scenario$agents
  ))
}

#' Calculate Dynamic Coincidence Factors
#' 
#' Applies the dynamic coincidence factor formula: FC = 0.222 + 0.036*e^(-0.0003n)
#' 
#' @param simulation_results Raw simulation results
#' @param config Configuration parameters
#' @return Results with coincidence factors applied
calculate_coincidence_factors <- function(simulation_results, config) {
  n_vehicles <- config$vehicles$num_vehicles
  
  # Calculate coincidence factor
  coincidence_factor <- 0.222 + 0.036 * exp(-0.0003 * n_vehicles)
  
  # Apply to all simulation results
  adjusted_results <- simulation_results
  for (i in seq_along(adjusted_results)) {
    adjusted_results[[i]]$total_demand_adjusted <- 
      adjusted_results[[i]]$total_demand * coincidence_factor
    adjusted_results[[i]]$coincidence_factor <- coincidence_factor
  }
  
  return(adjusted_results)
}

#' Generate Simulation ID
#' 
#' Creates a unique simulation identifier
#' 
#' @return Character simulation ID
generate_simulation_id <- function() {
  paste0("EV_SIM_", format(Sys.time(), "%Y%m%d_%H%M%S"), "_", 
         sample(1000:9999, 1))
}

# Helper functions (simplified implementations)
create_time_series <- function(start_date, days, resolution) {
  end_date <- start_date + days - 1
  seq(as.POSIXct(paste(start_date, "00:00:00")),
      as.POSIXct(paste(end_date, "23:59:59")),
      by = paste(resolution, "min"))
}

generate_daily_patterns <- function(agent, days, charging_config, behavioral_config) {
  # Simplified daily pattern generation
  # In full implementation, this would include sophisticated behavioral modeling
  patterns <- list()
  
  for (day in 1:days) {
    # Generate charging events based on agent characteristics
    charging_events <- generate_charging_events(agent, charging_config, behavioral_config)
    patterns[[day]] <- charging_events
  }
  
  return(patterns)
}

generate_charging_events <- function(agent, charging_config, behavioral_config) {
  events <- list()
  
  # Home charging event
  if (agent$home_charging && runif(1) < charging_config$home_charging_prob) {
    start_time <- max(0, min(24, rnorm(1, 
      charging_config$charging_start_times$home$mean,
      charging_config$charging_start_times$home$sd)))
    
    duration <- rweibull(1, 
      charging_config$charging_durations$home$shape,
      charging_config$charging_durations$home$scale)
    
    events$home <- list(
      start_time = start_time,
      duration = duration,
      power = agent$charging_power
    )
  }
  
  # Work charging event
  if (agent$work_charging && runif(1) < charging_config$work_charging_prob) {
    start_time <- max(0, min(24, rnorm(1,
      charging_config$charging_start_times$work$mean,
      charging_config$charging_start_times$work$sd)))
    
    duration <- rweibull(1,
      charging_config$charging_durations$work$shape,
      charging_config$charging_durations$work$scale)
    
    events$work <- list(
      start_time = start_time,
      duration = duration, 
      power = agent$charging_power
    )
  }
  
  return(events)
}

patterns_to_timeseries <- function(daily_patterns, time_series, resolution) {
  # Convert daily patterns to continuous time series
  # Simplified implementation
  demand_vector <- rep(0, length(time_series))
  
  for (day_idx in seq_along(daily_patterns)) {
    day_patterns <- daily_patterns[[day_idx]]
    
    # Convert each charging event to time series
    for (location in names(day_patterns)) {
      event <- day_patterns[[location]]
      if (!is.null(event)) {
        # Convert to time indices
        start_idx <- round(event$start_time * 60 / resolution) + 
                    (day_idx - 1) * (24 * 60 / resolution)
        end_idx <- start_idx + round(event$duration * 60 / resolution)
        
        # Ensure indices are within bounds
        start_idx <- max(1, min(start_idx, length(demand_vector)))
        end_idx <- max(1, min(end_idx, length(demand_vector)))
        
        if (end_idx > start_idx) {
          demand_vector[start_idx:end_idx] <- event$power
        }
      }
    }
  }
  
  return(demand_vector)
}

process_simulation_results <- function(results, config, agents) {
  # Process and aggregate Monte Carlo results
  # This would include statistical analysis, confidence intervals, etc.
  return(results)
}

generate_summary_statistics <- function(results, config) {
  # Generate comprehensive summary statistics
  return(list(
    total_runs = length(results),
    mean_daily_demand = mean(sapply(results, function(x) mean(x$total_demand))),
    peak_demand = max(sapply(results, function(x) max(x$total_demand))),
    load_factor = mean(sapply(results, function(x) mean(x$total_demand) / max(x$total_demand)))
  ))
}

cleanup_simulation <- function(sim_env) {
  # Cleanup parallel processing and GPU resources
  if (exists("cluster", envir = .GlobalEnv)) {
    parallel::stopCluster(get("cluster", envir = .GlobalEnv))
  }
}

# Export main functions
export_functions <- c(
  "run_final_simulation",
  "get_default_config", 
  "validate_config",
  "generate_ev_agents",
  "calculate_coincidence_factors"
)