# ==============================================================================
# load_csv_data.R - CSV Data Loading Script for EV Simulation Database
# ==============================================================================
#
# This script loads all CSV data files into the PostgreSQL/TimescaleDB database
# after the schema has been created using complete_schema_with_source_tables.sql
#
# Author: Iván Sánchez-Loor, Manuel Ayala-Chauvin
# ==============================================================================

# Load required libraries
suppressPackageStartupMessages({
  library(DBI)
  library(RPostgres)
  library(readr)
  library(dplyr)
  library(lubridate)
  library(glue)
})

# Database connection parameters
DB_CONFIG <- list(
  host = Sys.getenv("DB_HOST", "localhost"),
  port = as.integer(Sys.getenv("DB_PORT", "5432")),
  dbname = Sys.getenv("DB_NAME", "ev_simulation_db"),
  user = Sys.getenv("DB_USER", "postgres"),
  password = Sys.getenv("DB_PASSWORD", "")
)

# Data directory path
DATA_DIR <- "C:/Users/LEGION/Maestria BigData/Trabajo Titulacion/ev-demand-modeling-abm-timescaledb/database"

# ==============================================================================
# UTILITY FUNCTIONS
# ==============================================================================

#' Connect to database with error handling
connect_database <- function() {
  tryCatch({
    con <- dbConnect(
      RPostgres::Postgres(),
      host = DB_CONFIG$host,
      port = DB_CONFIG$port,
      dbname = DB_CONFIG$dbname,
      user = DB_CONFIG$user,
      password = DB_CONFIG$password
    )
    cat("✅ Database connection established successfully\n")
    return(con)
  }, error = function(e) {
    cat("❌ Error connecting to database:", conditionMessage(e), "\n")
    cat("Please ensure PostgreSQL is running and credentials are correct\n")
    return(NULL)
  })
}

#' Load CSV with proper data types and error handling
load_csv_safe <- function(file_path, col_types = NULL) {
  tryCatch({
    if (is.null(col_types)) {
      data <- readr::read_csv(file_path, locale = locale(encoding = "UTF-8"))
    } else {
      data <- readr::read_csv(file_path, col_types = col_types, locale = locale(encoding = "UTF-8"))
    }
    cat("✅ Loaded", nrow(data), "rows from", basename(file_path), "\n")
    return(data)
  }, error = function(e) {
    cat("❌ Error loading", file_path, ":", conditionMessage(e), "\n")
    return(NULL)
  })
}

#' Insert data into table with error handling
insert_data_safe <- function(con, table_name, data) {
  tryCatch({
    # Clear existing data
    dbExecute(con, glue("TRUNCATE TABLE {table_name} CASCADE"))
    
    # Insert new data
    dbWriteTable(con, table_name, data, append = TRUE, row.names = FALSE)
    
    # Get row count
    row_count <- dbGetQuery(con, glue("SELECT COUNT(*) as count FROM {table_name}"))$count
    cat("✅ Inserted", row_count, "rows into", table_name, "\n")
    return(TRUE)
  }, error = function(e) {
    cat("❌ Error inserting data into", table_name, ":", conditionMessage(e), "\n")
    return(FALSE)
  })
}

# ==============================================================================
# DATA LOADING FUNCTIONS
# ==============================================================================

#' Load cantones data with proper delimiter handling
load_cantones_data <- function(con) {
  cat("\n📍 Loading cantones_pichincha data...\n")
  
  # Read with semicolon delimiter (detected from file)
  data <- tryCatch({
    readr::read_delim(
      file.path(DATA_DIR, "cantones_pichincha.csv"),
      delim = ";",
      locale = locale(encoding = "UTF-8")
    )
  }, error = function(e) {
    cat("❌ Error loading cantones data:", conditionMessage(e), "\n")
    return(NULL)
  })
  
  if (is.null(data)) return(FALSE)
  
  # Fix coordinate formats (remove extra periods)
  data <- data %>%
    mutate(
      latitude = as.numeric(gsub("([0-9.-]+)\\.000$", "\\1", latitude)),
      longitude = as.numeric(gsub("([0-9.-]+)\\.000$", "\\1", longitude)),
      created_at = as.POSIXct(created_at, tz = "America/Guayaquil")
    )
  
  return(insert_data_safe(con, "cantones_pichincha", data))
}

#' Load tariffs data
load_tariffs_data <- function(con) {
  cat("\n💰 Loading ev_tariffs_quarter_hourly data...\n")
  
  data <- load_csv_safe(file.path(DATA_DIR, "ev_tariffs_quarter_hourly.csv"))
  if (is.null(data)) return(FALSE)
  
  # Add missing columns that are in schema but not CSV
  data <- data %>%
    mutate(
      id = row_number(), # Will be overwritten by SERIAL
      created_at = now()
    ) %>%
    select(-id) # Remove to let SERIAL handle it
  
  return(insert_data_safe(con, "ev_tariffs_quarter_hourly", data))
}

#' Load EV models catalog
load_ev_models_data <- function(con) {
  cat("\n🚗 Loading ev_models_catalog data...\n")
  
  data <- load_csv_safe(file.path(DATA_DIR, "ev_models_catalog.csv"))
  if (is.null(data)) return(FALSE)
  
  # Convert timestamps
  data <- data %>%
    mutate(
      created_at = as.POSIXct(created_at, tz = "America/Guayaquil"),
      updated_at = as.POSIXct(updated_at, tz = "America/Guayaquil")
    )
  
  return(insert_data_safe(con, "ev_models_catalog", data))
}

#' Load charging profiles data
load_charging_profiles_data <- function(con) {
  cat("\n🔋 Loading charging_profiles data...\n")
  
  data <- load_csv_safe(file.path(DATA_DIR, "charging_profiles..csv"))
  if (is.null(data)) return(FALSE)
  
  # Convert timestamps and handle NULLs
  data <- data %>%
    mutate(
      created_at = as.POSIXct(created_at, tz = "America/Guayaquil"),
      generation_timestamp = as.POSIXct(generation_timestamp, tz = "America/Guayaquil"),
      is_validated = ifelse(is.na(is_validated), TRUE, is_validated)
    )
  
  return(insert_data_safe(con, "charging_profiles", data))
}

#' Load provincial projections
load_provincial_projections_data <- function(con) {
  cat("\n📊 Loading ev_provincial_projections data...\n")
  
  data <- load_csv_safe(file.path(DATA_DIR, "ev_provincial_projections.csv"))
  if (is.null(data)) return(FALSE)
  
  # Transform CSV columns to match schema
  data <- data %>%
    mutate(
      period_date = as.Date(period_date),
      created_at = as.POSIXct(loaded_at, tz = "America/Guayaquil"),
      updated_at = as.POSIXct(loaded_at, tz = "America/Guayaquil"),
      methodology = data_source,
      confidence_level = 0.8  # Default confidence level
    ) %>%
    select(-loaded_at, -data_source, -period_raw) %>%
    filter(province_name == "Pichincha")  # Focus on target province
  
  return(insert_data_safe(con, "ev_provincial_projections", data))
}

#' Load temperature profiles
load_temperature_profiles_data <- function(con) {
  cat("\n🌡️ Loading bethania_weekly_monthly_profiles_v3 data...\n")
  
  data <- load_csv_safe(file.path(DATA_DIR, "bethania_weekly_monthly_profiles_v3.csv"))
  if (is.null(data)) return(FALSE)
  
  # Transform Spanish CSV to English schema
  month_mapping <- c("Enero" = 1, "Febrero" = 2, "Marzo" = 3, "Abril" = 4,
                    "Mayo" = 5, "Junio" = 6, "Julio" = 7, "Agosto" = 8, 
                    "Septiembre" = 9, "Octubre" = 10, "Noviembre" = 11, "Diciembre" = 12)
  
  data <- data %>%
    mutate(
      month = month_mapping[mes],
      week_of_month = case_when(
        dia_semana == "Domingo" ~ 1,
        dia_semana == "Lunes" ~ 2,
        dia_semana == "Martes" ~ 3,
        dia_semana == "Miercoles" ~ 4,
        dia_semana == "Jueves" ~ 5,
        dia_semana == "Viernes" ~ 6,
        dia_semana == "Sabado" ~ 7,
        TRUE ~ 1
      ) %% 5 + 1,  # Convert to week of month (1-5)
      temperature_celsius = as.numeric(temperatura_promedio),
      humidity_percentage = 65.0,      # Default value
      precipitation_mm = 0.0,          # Default value
      data_source = fuente_datos,
      measurement_year = 2023,         # Default year
      created_at = now()
    ) %>%
    select(month, week_of_month, temperature_celsius, humidity_percentage, 
           precipitation_mm, data_source, measurement_year, created_at) %>%
    filter(!is.na(month)) %>%  # Remove any unmapped months
    distinct()  # Remove duplicates
  
  return(insert_data_safe(con, "bethania_weekly_monthly_profiles_v3", data))
}

#' Load battery degradation profiles
load_battery_degradation_data <- function(con) {
  cat("\n🔋 Loading battery_degradation_profiles data...\n")
  
  data <- load_csv_safe(file.path(DATA_DIR, "battery_degradation_profiles.csv"))
  if (is.null(data)) return(FALSE)
  
  # Transform CSV to match schema structure
  data <- data %>%
    mutate(
      years_of_use = as.numeric(vehicle_age_years),
      cycles_accumulated = as.integer(cycle_count),
      degradation_factor = as.numeric(degradation_factor),
      capacity_retention_percent = as.numeric(capacity_retention_percent),
      temperature_impact_factor = 1.0 + (temperature_celsius - 20) * 0.01, # Temperature correction
      usage_intensity = case_when(
        cycle_count > 150 ~ "high",
        cycle_count > 75 ~ "normal", 
        TRUE ~ "low"
      ),
      created_at = now()
    ) %>%
    select(battery_chemistry, years_of_use, cycles_accumulated, degradation_factor,
           capacity_retention_percent, temperature_impact_factor, usage_intensity, created_at) %>%
    distinct(battery_chemistry, years_of_use, usage_intensity, .keep_all = TRUE)
  
  return(insert_data_safe(con, "battery_degradation_profiles", data))
}

#' Load charging patterns with format conversion
load_charging_patterns_data <- function(con) {
  cat("\n⚡ Loading ev_charging_patterns_15min data...\n")
  
  data <- load_csv_safe(file.path(DATA_DIR, "ev_charging_patterns_15min.csv"))
  if (is.null(data)) return(FALSE)
  
  # Convert Spanish column names to English schema
  # The CSV has: nombre_dia, cuarto_hora_index, probabilidad, metodologia, created_at
  # Schema expects: quarter_hour, hour_of_day, minute_of_hour, weekday, weekend, pattern_type, data_source, created_at
  
  # Transform the data to match schema
  transformed_data <- data %>%
    rename(
      quarter_hour = cuarto_hora_index,
      data_source = metodologia
    ) %>%
    mutate(
      hour_of_day = quarter_hour %/% 4,
      minute_of_hour = (quarter_hour %% 4) * 15,
      weekday = ifelse(nombre_dia %in% c("Monday", "Tuesday", "Wednesday", "Thursday", "Friday"), 
                      as.numeric(probabilidad) / 100, 0),
      weekend = ifelse(nombre_dia %in% c("Saturday", "Sunday"), 
                      as.numeric(probabilidad) / 100, 0),
      pattern_type = "residential",
      created_at = as.POSIXct(created_at, tz = "America/Guayaquil")
    ) %>%
    select(-nombre_dia, -probabilidad) %>%
    group_by(quarter_hour, hour_of_day, minute_of_hour, pattern_type, data_source) %>%
    summarise(
      weekday = mean(weekday, na.rm = TRUE),
      weekend = mean(weekend, na.rm = TRUE),
      created_at = first(created_at),
      .groups = "drop"
    )
  
  return(insert_data_safe(con, "ev_charging_patterns_15min", transformed_data))
}

# ==============================================================================
# MAIN EXECUTION FUNCTION
# ==============================================================================

#' Main function to load all CSV data
main <- function() {
  cat("🚀 Starting CSV data loading process...\n")
  cat("📂 Data directory:", DATA_DIR, "\n\n")
  
  # Connect to database
  con <- connect_database()
  if (is.null(con)) {
    cat("❌ Cannot proceed without database connection\n")
    return(FALSE)
  }
  
  # Ensure we disconnect on exit
  on.exit(dbDisconnect(con))
  
  # Load data in dependency order
  results <- list()
  
  results$cantones <- load_cantones_data(con)
  results$tariffs <- load_tariffs_data(con)
  results$ev_models <- load_ev_models_data(con)
  results$charging_profiles <- load_charging_profiles_data(con)  # Depends on ev_models
  results$projections <- load_provincial_projections_data(con)
  results$temperature <- load_temperature_profiles_data(con)
  results$battery_degradation <- load_battery_degradation_data(con)
  results$charging_patterns <- load_charging_patterns_data(con)
  
  # Summary
  cat("\n" , "="*60, "\n")
  cat("📋 LOADING SUMMARY\n")
  cat("="*60, "\n")
  
  success_count <- sum(unlist(results))
  total_count <- length(results)
  
  for (name in names(results)) {
    status <- if(results[[name]]) "✅ SUCCESS" else "❌ FAILED"
    cat(sprintf("%-25s: %s\n", name, status))
  }
  
  cat("="*60, "\n")
  cat(sprintf("Overall result: %d/%d tables loaded successfully\n", success_count, total_count))
  
  if (success_count == total_count) {
    cat("🎉 All data loaded successfully! Database is ready for simulation.\n")
    
    # Run data completeness report
    cat("\n📊 Running data completeness check...\n")
    completeness <- dbGetQuery(con, "SELECT * FROM get_data_completeness_report() ORDER BY table_name")
    print(completeness)
    
    return(TRUE)
  } else {
    cat("⚠️  Some tables failed to load. Please check error messages above.\n")
    return(FALSE)
  }
}

# ==============================================================================
# EXECUTION
# ==============================================================================

if (!interactive()) {
  # Running as script
  success <- main()
  if (!success) {
    quit(status = 1)
  }
} else {
  cat("📝 Script loaded. Run main() to execute data loading.\n")
  cat("💡 Example: source('load_csv_data.R'); main()\n")
}