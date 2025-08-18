# ==============================================================================
# data_manager.R - Data Management Module for EV Demand Modeling Framework
# ==============================================================================
#
# This module handles all data management operations including:
# - TimescaleDB connection and operations
# - Data import/export functionality
# - Real-time data streaming
# - Data validation and quality checks
# - Backup and recovery operations
#
# Author: Iván Sánchez-Loor, Manuel Ayala-Chauvin
# Institution: Universidad Indoamérica - SISAu Research Group
# ==============================================================================

# Load required libraries
suppressPackageStartupMessages({
  library(DBI)
  library(RPostgres)
  library(pool)
  library(dplyr)
  library(tidyr)
  library(readr)
  library(lubridate)
  library(config)
  library(jsonlite)
})

# Global connection pool (initialized later)
.connection_pool <- NULL

#' Initialize Database Connection Pool
#' 
#' Creates a connection pool to TimescaleDB for efficient database operations
#' 
#' @param db_config Database configuration list
#' @param pool_size Maximum number of connections in pool
#' @param verbose Logical: print connection status
#' @return Logical: TRUE if successful
initialize_db_pool <- function(db_config = NULL, pool_size = 10, verbose = TRUE) {
  if (verbose) cat("🔌 Initializing TimescaleDB connection pool...\n")
  
  # Load configuration if not provided
  if (is.null(db_config)) {
    db_config <- get_db_config()
  }
  
  tryCatch({
    # Create connection pool
    .connection_pool <<- pool::dbPool(
      drv = RPostgres::Postgres(),
      host = db_config$host,
      port = db_config$port,
      dbname = db_config$dbname,
      user = db_config$user,
      password = db_config$password,
      minSize = 2,
      maxSize = pool_size,
      idleTimeout = 3600000  # 1 hour
    )
    
    # Test connection
    test_connection <- pool::poolCheckout(.connection_pool)
    pool::poolReturn(test_connection)
    
    if (verbose) {
      cat("✅ Database connection pool initialized\n")
      cat(sprintf("   🏠 Host: %s:%s\n", db_config$host, db_config$port))
      cat(sprintf("   🗄️  Database: %s\n", db_config$dbname))
      cat(sprintf("   👤 User: %s\n", db_config$user))
      cat(sprintf("   🔗 Pool size: %d\n", pool_size))
    }
    
    return(TRUE)
    
  }, error = function(e) {
    if (verbose) cat("❌ Failed to initialize database pool:", e$message, "\n")
    return(FALSE)
  })
}

#' Get Database Configuration
#' 
#' Loads database configuration from config file or environment
#' 
#' @param config_file Path to configuration file
#' @return Database configuration list
get_db_config <- function(config_file = "config.yml") {
  # Try to load from config file
  if (file.exists(config_file)) {
    tryCatch({
      conf <- config::get(file = config_file)
      if (!is.null(conf$database)) {
        return(conf$database)
      }
    }, error = function(e) {
      warning("Could not load config file: ", e$message)
    })
  }
  
  # Try environment variables
  db_config <- list(
    host = Sys.getenv("DB_HOST", "localhost"),
    port = as.integer(Sys.getenv("DB_PORT", "5432")),
    dbname = Sys.getenv("DB_NAME", "ev_simulation_db"),
    user = Sys.getenv("DB_USER", "postgres"),
    password = Sys.getenv("DB_PASSWORD", "")
  )
  
  # Validate required parameters
  if (db_config$password == "") {
    stop("Database password not found in config file or DB_PASSWORD environment variable")
  }
  
  return(db_config)
}

#' Execute Database Query
#' 
#' Executes a query using the connection pool
#' 
#' @param query SQL query string
#' @param params Query parameters (optional)
#' @param fetch_result Logical: whether to fetch results
#' @return Query results or NULL
execute_db_query <- function(query, params = NULL, fetch_result = TRUE) {
  if (is.null(.connection_pool)) {
    stop("Database connection pool not initialized. Call initialize_db_pool() first.")
  }
  
  tryCatch({
    if (fetch_result) {
      if (is.null(params)) {
        result <- pool::dbGetQuery(.connection_pool, query)
      } else {
        result <- pool::dbGetQuery(.connection_pool, query, params = params)
      }
      return(result)
    } else {
      if (is.null(params)) {
        pool::dbExecute(.connection_pool, query)
      } else {
        pool::dbExecute(.connection_pool, query, params = params)
      }
      return(NULL)
    }
  }, error = function(e) {
    stop("Database query failed: ", e$message, "\nQuery: ", query)
  })
}

#' Save Simulation Results to Database
#' 
#' Saves simulation results to TimescaleDB with proper time-series optimization
#' 
#' @param simulation_results List containing simulation results
#' @param config Configuration parameters
#' @param batch_size Number of records per batch insert
#' @return Logical: TRUE if successful
save_results_to_db <- function(simulation_results, config, batch_size = 10000) {
  if (is.null(.connection_pool)) {
    warning("Database not available, skipping save")
    return(FALSE)
  }
  
  cat("💾 Saving simulation results to TimescaleDB...\n")
  
  tryCatch({
    # Extract metadata
    simulation_id <- simulation_results$metadata$simulation_id
    timestamp <- simulation_results$metadata$timestamp
    
    # Save simulation metadata
    save_simulation_metadata(simulation_results, config)
    
    # Process and save time series data
    total_records <- 0
    
    for (run_idx in seq_along(simulation_results$results)) {
      run_data <- simulation_results$results[[run_idx]]
      
      # Prepare time series data
      ts_data <- prepare_timeseries_data(
        run_data, 
        simulation_id, 
        run_idx
      )
      
      # Save in batches
      n_batches <- ceiling(nrow(ts_data) / batch_size)
      
      for (batch in 1:n_batches) {
        start_idx <- (batch - 1) * batch_size + 1
        end_idx <- min(batch * batch_size, nrow(ts_data))
        batch_data <- ts_data[start_idx:end_idx, ]
        
        # Insert batch
        save_timeseries_batch(batch_data)
        total_records <- total_records + nrow(batch_data)
      }
    }
    
    # Save agent data
    save_agent_data(simulation_results$agents, simulation_id)
    
    # Save aggregated statistics
    save_summary_statistics(simulation_results$summary, simulation_id)
    
    cat(sprintf("✅ Saved %s records to database\n", format(total_records, big.mark = ",")))
    return(TRUE)
    
  }, error = function(e) {
    cat("❌ Failed to save to database:", e$message, "\n")
    return(FALSE)
  })
}

#' Prepare Time Series Data
#' 
#' Converts simulation results to TimescaleDB format
#' 
#' @param run_data Single simulation run data
#' @param simulation_id Unique simulation identifier
#' @param run_id Monte Carlo run identifier
#' @return Data frame formatted for database
prepare_timeseries_data <- function(run_data, simulation_id, run_id) {
  data.frame(
    simulation_id = simulation_id,
    run_id = run_id,
    timestamp = run_data$time_series,
    total_demand = run_data$total_demand_adjusted,
    raw_demand = run_data$total_demand,
    coincidence_factor = run_data$coincidence_factor,
    n_vehicles = nrow(run_data$agents),
    stringsAsFactors = FALSE
  )
}

#' Save Simulation Metadata
#' 
#' Saves simulation configuration and metadata
#' 
#' @param simulation_results Complete simulation results
#' @param config Configuration parameters
save_simulation_metadata <- function(simulation_results, config) {
  metadata <- simulation_results$metadata
  
  query <- "
    INSERT INTO simulation_metadata (
      simulation_id, timestamp, config_json, processing_engine,
      duration_seconds, n_vehicles, n_runs, days_simulated
    ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
    ON CONFLICT (simulation_id) DO UPDATE SET
      timestamp = EXCLUDED.timestamp,
      config_json = EXCLUDED.config_json
  "
  
  execute_db_query(
    query,
    params = list(
      metadata$simulation_id,
      metadata$timestamp,
      jsonlite::toJSON(config, auto_unbox = TRUE),
      metadata$processing_engine,
      as.numeric(metadata$duration, units = "secs"),
      config$vehicles$num_vehicles,
      length(simulation_results$results),
      config$simulation$days
    ),
    fetch_result = FALSE
  )
}

#' Save Time Series Batch
#' 
#' Saves a batch of time series data using COPY for performance
#' 
#' @param batch_data Data frame with time series data
save_timeseries_batch <- function(batch_data) {
  # Use COPY for high-performance bulk insert
  query <- "
    COPY ev_demand_timeseries (
      simulation_id, run_id, timestamp, total_demand, 
      raw_demand, coincidence_factor, n_vehicles
    ) FROM STDIN WITH (FORMAT CSV, HEADER TRUE)
  "
  
  # Create temporary CSV
  temp_file <- tempfile(fileext = ".csv")
  on.exit(unlink(temp_file))
  
  write_csv(batch_data, temp_file)
  
  # Use COPY command (implementation depends on database driver)
  conn <- pool::poolCheckout(.connection_pool)
  on.exit(pool::poolReturn(conn), add = TRUE)
  
  tryCatch({
    # Use dbSendQuery with COPY FROM STDIN
    result <- DBI::dbSendQuery(conn, query)
    
    # Send CSV data
    file_content <- paste(readLines(temp_file), collapse = "\n")
    DBI::dbSendQuery(conn, file_content)
    
    DBI::dbClearResult(result)
  }, error = function(e) {
    # Fallback to regular INSERT if COPY fails
    DBI::dbAppendTable(conn, "ev_demand_timeseries", batch_data)
  })
}

#' Save Agent Data
#' 
#' Saves EV agent characteristics to database
#' 
#' @param agents Agent data frame
#' @param simulation_id Simulation identifier
save_agent_data <- function(agents, simulation_id) {
  # Add simulation_id to agents data
  agents$simulation_id <- simulation_id
  
  # Reorder columns
  agents <- agents[, c("simulation_id", "agent_id", "vehicle_type", 
                      "battery_capacity", "charging_power", "efficiency",
                      "annual_mileage", "daily_distance", "home_charging",
                      "work_charging", "soc_start_threshold", "soc_end_threshold",
                      "convenience_factor", "time_flexibility")]
  
  conn <- pool::poolCheckout(.connection_pool)
  on.exit(pool::poolReturn(conn))
  
  # Clear existing data for this simulation
  DBI::dbExecute(conn, 
                "DELETE FROM ev_agents WHERE simulation_id = $1",
                params = list(simulation_id))
  
  # Insert new data
  DBI::dbAppendTable(conn, "ev_agents", agents)
}

#' Save Summary Statistics
#' 
#' Saves aggregated simulation statistics
#' 
#' @param summary_stats Summary statistics list
#' @param simulation_id Simulation identifier
save_summary_statistics <- function(summary_stats, simulation_id) {
  query <- "
    INSERT INTO simulation_summary (
      simulation_id, total_runs, mean_daily_demand, 
      peak_demand, load_factor, created_at
    ) VALUES ($1, $2, $3, $4, $5, NOW())
    ON CONFLICT (simulation_id) DO UPDATE SET
      total_runs = EXCLUDED.total_runs,
      mean_daily_demand = EXCLUDED.mean_daily_demand,
      peak_demand = EXCLUDED.peak_demand,
      load_factor = EXCLUDED.load_factor,
      created_at = EXCLUDED.created_at
  "
  
  execute_db_query(
    query,
    params = list(
      simulation_id,
      summary_stats$total_runs,
      summary_stats$mean_daily_demand,
      summary_stats$peak_demand,
      summary_stats$load_factor
    ),
    fetch_result = FALSE
  )
}

#' Load Simulation Results
#' 
#' Loads previously saved simulation results from database
#' 
#' @param simulation_id Simulation identifier
#' @param include_individual Logical: include individual run data
#' @return List with simulation results
load_simulation_results <- function(simulation_id, include_individual = FALSE) {
  if (is.null(.connection_pool)) {
    stop("Database connection pool not initialized")
  }
  
  cat(sprintf("📖 Loading simulation results for ID: %s\n", simulation_id))
  
  # Load metadata
  metadata_query <- "
    SELECT * FROM simulation_metadata 
    WHERE simulation_id = $1
  "
  metadata <- execute_db_query(metadata_query, params = list(simulation_id))
  
  if (nrow(metadata) == 0) {
    stop("Simulation ID not found: ", simulation_id)
  }
  
  # Load summary statistics
  summary_query <- "
    SELECT * FROM simulation_summary 
    WHERE simulation_id = $1
  "
  summary <- execute_db_query(summary_query, params = list(simulation_id))
  
  # Load agent data
  agents_query <- "
    SELECT * FROM ev_agents 
    WHERE simulation_id = $1
    ORDER BY agent_id
  "
  agents <- execute_db_query(agents_query, params = list(simulation_id))
  
  result <- list(
    metadata = metadata,
    summary = summary,
    agents = agents
  )
  
  # Load individual run data if requested
  if (include_individual) {
    timeseries_query <- "
      SELECT * FROM ev_demand_timeseries 
      WHERE simulation_id = $1
      ORDER BY run_id, timestamp
    "
    timeseries <- execute_db_query(timeseries_query, params = list(simulation_id))
    result$timeseries <- timeseries
  }
  
  cat("✅ Simulation results loaded successfully\n")
  return(result)
}

#' Export Simulation Data
#' 
#' Exports simulation data to various formats
#' 
#' @param simulation_id Simulation identifier
#' @param format Export format: "csv", "parquet", "json"
#' @param output_dir Output directory
#' @return Logical: TRUE if successful
export_simulation_data <- function(simulation_id, format = "csv", output_dir = "exports") {
  cat(sprintf("📤 Exporting simulation data (%s format)...\n", format))
  
  # Create output directory
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }
  
  # Load data
  data <- load_simulation_results(simulation_id, include_individual = TRUE)
  
  timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  
  tryCatch({
    if (format == "csv") {
      # Export as CSV files
      write_csv(data$metadata, file.path(output_dir, paste0(simulation_id, "_metadata_", timestamp, ".csv")))
      write_csv(data$summary, file.path(output_dir, paste0(simulation_id, "_summary_", timestamp, ".csv")))
      write_csv(data$agents, file.path(output_dir, paste0(simulation_id, "_agents_", timestamp, ".csv")))
      write_csv(data$timeseries, file.path(output_dir, paste0(simulation_id, "_timeseries_", timestamp, ".csv")))
      
    } else if (format == "json") {
      # Export as JSON
      json_data <- jsonlite::toJSON(data, pretty = TRUE, auto_unbox = TRUE)
      writeLines(json_data, file.path(output_dir, paste0(simulation_id, "_complete_", timestamp, ".json")))
      
    } else if (format == "parquet") {
      # Export as Parquet (requires arrow package)
      if (requireNamespace("arrow", quietly = TRUE)) {
        arrow::write_parquet(data$timeseries, file.path(output_dir, paste0(simulation_id, "_timeseries_", timestamp, ".parquet")))
        arrow::write_parquet(data$agents, file.path(output_dir, paste0(simulation_id, "_agents_", timestamp, ".parquet")))
      } else {
        stop("Arrow package required for Parquet export")
      }
    }
    
    cat("✅ Data exported successfully\n")
    return(TRUE)
    
  }, error = function(e) {
    cat("❌ Export failed:", e$message, "\n")
    return(FALSE)
  })
}

#' Database Health Check
#' 
#' Performs comprehensive database health check
#' 
#' @return List with health check results
check_database_health <- function() {
  if (is.null(.connection_pool)) {
    return(list(status = "ERROR", message = "No database connection"))
  }
  
  health_results <- list()
  
  tryCatch({
    # Test basic connectivity
    test_query <- "SELECT 1 as test"
    test_result <- execute_db_query(test_query)
    health_results$connectivity <- "OK"
    
    # Check TimescaleDB extension
    extension_query <- "SELECT * FROM pg_extension WHERE extname = 'timescaledb'"
    extension_result <- execute_db_query(extension_query)
    health_results$timescaledb <- if (nrow(extension_result) > 0) "OK" else "NOT_INSTALLED"
    
    # Check table existence
    tables_query <- "
      SELECT table_name 
      FROM information_schema.tables 
      WHERE table_schema = 'public' 
        AND table_name IN ('simulation_metadata', 'ev_demand_timeseries', 'ev_agents')
    "
    tables_result <- execute_db_query(tables_query)
    health_results$required_tables <- nrow(tables_result)
    
    # Check hypertable status
    if (health_results$timescaledb == "OK") {
      hypertable_query <- "
        SELECT * FROM _timescaledb_catalog.hypertable 
        WHERE table_name = 'ev_demand_timeseries'
      "
      hypertable_result <- execute_db_query(hypertable_query)
      health_results$hypertable_status <- if (nrow(hypertable_result) > 0) "OK" else "NOT_CONFIGURED"
    }
    
    # Check disk space (PostgreSQL specific)
    disk_query <- "
      SELECT 
        pg_size_pretty(pg_database_size(current_database())) as database_size,
        pg_size_pretty(pg_total_relation_size('ev_demand_timeseries')) as timeseries_size
    "
    disk_result <- execute_db_query(disk_query)
    health_results$storage <- disk_result
    
    health_results$status <- "OK"
    health_results$timestamp <- Sys.time()
    
  }, error = function(e) {
    health_results$status <- "ERROR"
    health_results$error_message <- e$message
  })
  
  return(health_results)
}

#' Close Database Pool
#' 
#' Properly closes the database connection pool
close_db_pool <- function() {
  if (!is.null(.connection_pool)) {
    pool::poolClose(.connection_pool)
    .connection_pool <<- NULL
    cat("🔌 Database connection pool closed\n")
  }
}

# Cleanup on package unload
.onUnload <- function(libpath) {
  close_db_pool()
}

cat("📊 Data management module loaded successfully\n")