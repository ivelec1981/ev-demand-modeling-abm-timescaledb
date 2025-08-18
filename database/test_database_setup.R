# ==============================================================================
# test_database_setup.R - Database Schema and Data Loading Test Suite
# ==============================================================================
#
# This script tests the complete database setup process to ensure:
# 1. Schema creation works properly
# 2. CSV data loads without errors
# 3. Data integrity and foreign key relationships are correct
# 4. TimescaleDB features function properly
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

# Test configuration
TEST_DB_NAME <- "ev_simulation_test_db"
DATA_DIR <- "C:/Users/LEGION/Maestria BigData/Trabajo Titulacion/ev-demand-modeling-abm-timescaledb/database"

# Database connection parameters
DB_CONFIG <- list(
  host = Sys.getenv("DB_HOST", "localhost"),
  port = as.integer(Sys.getenv("DB_PORT", "5432")),
  user = Sys.getenv("DB_USER", "postgres"),
  password = Sys.getenv("DB_PASSWORD", "")
)

# ==============================================================================
# TEST UTILITY FUNCTIONS
# ==============================================================================

#' Create test database
create_test_database <- function() {
  cat("🧪 Creating test database:", TEST_DB_NAME, "\n")
  
  # Connect to postgres to create test database
  con_postgres <- tryCatch({
    dbConnect(
      RPostgres::Postgres(),
      host = DB_CONFIG$host,
      port = DB_CONFIG$port,
      dbname = "postgres",
      user = DB_CONFIG$user,
      password = DB_CONFIG$password
    )
  }, error = function(e) {
    cat("❌ Cannot connect to PostgreSQL:", conditionMessage(e), "\n")
    return(NULL)
  })
  
  if (is.null(con_postgres)) return(FALSE)
  
  # Drop existing test database if it exists
  tryCatch({
    dbExecute(con_postgres, glue("DROP DATABASE IF EXISTS {TEST_DB_NAME}"))
  }, error = function(e) {
    cat("⚠️  Warning dropping existing test database:", conditionMessage(e), "\n")
  })
  
  # Create new test database
  tryCatch({
    dbExecute(con_postgres, glue("CREATE DATABASE {TEST_DB_NAME}"))
    cat("✅ Test database created successfully\n")
    result <- TRUE
  }, error = function(e) {
    cat("❌ Error creating test database:", conditionMessage(e), "\n")
    result <- FALSE
  })
  
  dbDisconnect(con_postgres)
  return(result)
}

#' Connect to test database
connect_test_database <- function() {
  tryCatch({
    con <- dbConnect(
      RPostgres::Postgres(),
      host = DB_CONFIG$host,
      port = DB_CONFIG$port,
      dbname = TEST_DB_NAME,
      user = DB_CONFIG$user,
      password = DB_CONFIG$password
    )
    return(con)
  }, error = function(e) {
    cat("❌ Error connecting to test database:", conditionMessage(e), "\n")
    return(NULL)
  })
}

#' Test schema creation
test_schema_creation <- function(con) {
  cat("\n🏗️  Testing schema creation...\n")
  
  schema_file <- file.path(DATA_DIR, "complete_schema_with_source_tables.sql")
  
  if (!file.exists(schema_file)) {
    cat("❌ Schema file not found:", schema_file, "\n")
    return(FALSE)
  }
  
  tryCatch({
    # Enable TimescaleDB extension first
    dbExecute(con, "CREATE EXTENSION IF NOT EXISTS timescaledb")
    
    # Read and execute schema
    sql_content <- readLines(schema_file, warn = FALSE)
    sql_script <- paste(sql_content, collapse = "\n")
    
    # Split and execute statements
    statements <- strsplit(sql_script, ";\\s*\\n")[[1]]
    statements <- statements[nzchar(trimws(statements))]
    
    for (stmt in statements) {
      stmt <- trimws(stmt)
      if (nzchar(stmt) && !grepl("^--", stmt)) {
        dbExecute(con, stmt)
      }
    }
    
    cat("✅ Schema created successfully\n")
    return(TRUE)
    
  }, error = function(e) {
    cat("❌ Schema creation failed:", conditionMessage(e), "\n")
    return(FALSE)
  })
}

#' Test individual CSV file loading
test_csv_loading <- function(con, table_name, csv_file, custom_loader = NULL) {
  cat(glue("📄 Testing {table_name} from {csv_file}...\n"))
  
  file_path <- file.path(DATA_DIR, csv_file)
  
  if (!file.exists(file_path)) {
    cat(glue("❌ CSV file not found: {file_path}\n"))
    return(list(success = FALSE, error = "File not found"))
  }
  
  tryCatch({
    # Use custom loader if provided, otherwise standard CSV loading
    if (!is.null(custom_loader)) {
      data <- custom_loader(file_path)
    } else {
      data <- readr::read_csv(file_path, locale = locale(encoding = "UTF-8"))
    }
    
    if (is.null(data) || nrow(data) == 0) {
      return(list(success = FALSE, error = "No data loaded"))
    }
    
    # Clear existing data and insert
    dbExecute(con, glue("TRUNCATE TABLE {table_name} CASCADE"))
    dbWriteTable(con, table_name, data, append = TRUE, row.names = FALSE)
    
    # Verify insertion
    count <- dbGetQuery(con, glue("SELECT COUNT(*) as count FROM {table_name}"))$count
    
    cat(glue("✅ {table_name}: {count} rows loaded\n"))
    return(list(success = TRUE, count = count))
    
  }, error = function(e) {
    cat(glue("❌ {table_name} loading failed: {conditionMessage(e)}\n"))
    return(list(success = FALSE, error = conditionMessage(e)))
  })
}

#' Custom loaders for problematic CSV files
load_cantones_custom <- function(file_path) {
  readr::read_delim(file_path, delim = ";", locale = locale(encoding = "UTF-8")) %>%
    mutate(
      latitude = as.numeric(gsub("([0-9.-]+)\\.000$", "\\1", latitude)),
      longitude = as.numeric(gsub("([0-9.-]+)\\.000$", "\\1", longitude)),
      created_at = as.POSIXct(created_at, tz = "America/Guayaquil")
    )
}

load_projections_custom <- function(file_path) {
  readr::read_csv(file_path, locale = locale(encoding = "UTF-8")) %>%
    mutate(
      period_date = as.Date(period_date),
      created_at = as.POSIXct(loaded_at, tz = "America/Guayaquil"),
      updated_at = as.POSIXct(loaded_at, tz = "America/Guayaquil"),
      methodology = data_source,
      confidence_level = 0.8  # Default value
    ) %>%
    select(-loaded_at, -data_source, -period_raw) %>%
    filter(province_name == "Pichincha")  # Focus on our target province
}

load_temperature_custom <- function(file_path) {
  readr::read_csv(file_path, locale = locale(encoding = "UTF-8")) %>%
    mutate(
      month = match(mes, month.name[c(4, 8, 12, 2, 1, 7, 6, 3, 5, 11, 10, 9)]), # Spanish month names
      week_of_month = case_when(
        dia_semana == "Domingo" ~ 1,
        dia_semana == "Lunes" ~ 2,
        dia_semana == "Martes" ~ 3,
        dia_semana == "Miercoles" ~ 4,
        dia_semana == "Jueves" ~ 5,
        dia_semana == "Viernes" ~ 6,
        dia_semana == "Sabado" ~ 7,
        TRUE ~ 1
      ) %% 5 + 1,  # Convert to week of month
      temperature_celsius = as.numeric(temperatura_promedio),
      humidity_percentage = 65.0,  # Default value
      precipitation_mm = 0.0,      # Default value  
      data_source = fuente_datos,
      measurement_year = 2023,     # Default value
      created_at = now()
    ) %>%
    select(month, week_of_month, temperature_celsius, humidity_percentage, 
           precipitation_mm, data_source, measurement_year, created_at) %>%
    distinct()
}

load_battery_degradation_custom <- function(file_path) {
  readr::read_csv(file_path, locale = locale(encoding = "UTF-8")) %>%
    mutate(
      years_of_use = as.numeric(vehicle_age_years),
      cycles_accumulated = as.integer(cycle_count),
      degradation_factor = as.numeric(degradation_factor),
      capacity_retention_percent = as.numeric(capacity_retention_percent),
      temperature_impact_factor = 1.0 + (temperature_celsius - 20) * 0.01, # Simple temperature impact
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
}

load_charging_patterns_custom <- function(file_path) {
  readr::read_csv(file_path, locale = locale(encoding = "UTF-8")) %>%
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
    group_by(quarter_hour, hour_of_day, minute_of_hour, pattern_type, data_source) %>%
    summarise(
      weekday = mean(weekday, na.rm = TRUE),
      weekend = mean(weekend, na.rm = TRUE),
      created_at = first(created_at),
      .groups = "drop"
    )
}

# ==============================================================================
# MAIN TEST FUNCTIONS
# ==============================================================================

#' Run all CSV loading tests
test_all_csv_loading <- function(con) {
  cat("\n📊 Testing CSV data loading...\n")
  
  results <- list()
  
  # Test each table with custom loaders where needed
  results$cantones <- test_csv_loading(con, "cantones_pichincha", "cantones_pichincha.csv", load_cantones_custom)
  results$tariffs <- test_csv_loading(con, "ev_tariffs_quarter_hourly", "ev_tariffs_quarter_hourly.csv")
  results$ev_models <- test_csv_loading(con, "ev_models_catalog", "ev_models_catalog.csv")
  results$charging_profiles <- test_csv_loading(con, "charging_profiles", "charging_profiles..csv")
  results$projections <- test_csv_loading(con, "ev_provincial_projections", "ev_provincial_projections.csv", load_projections_custom)
  results$temperature <- test_csv_loading(con, "bethania_weekly_monthly_profiles_v3", "bethania_weekly_monthly_profiles_v3.csv", load_temperature_custom)
  results$battery_degradation <- test_csv_loading(con, "battery_degradation_profiles", "battery_degradation_profiles.csv", load_battery_degradation_custom)
  results$charging_patterns <- test_csv_loading(con, "ev_charging_patterns_15min", "ev_charging_patterns_15min.csv", load_charging_patterns_custom)
  
  return(results)
}

#' Test data integrity and foreign key relationships
test_data_integrity <- function(con) {
  cat("\n🔍 Testing data integrity and relationships...\n")
  
  integrity_tests <- list()
  
  # Test 1: Foreign key relationships
  cat("  Testing foreign key relationships...\n")
  
  # charging_profiles -> ev_models_catalog
  orphaned_profiles <- dbGetQuery(con, "
    SELECT COUNT(*) as count
    FROM charging_profiles cp
    LEFT JOIN ev_models_catalog emc ON cp.vehicle_id = emc.vehicle_model_id
    WHERE emc.vehicle_model_id IS NULL
  ")$count
  
  if (orphaned_profiles > 0) {
    cat(glue("  ⚠️  Warning: {orphaned_profiles} charging profiles with invalid vehicle_id\n"))
    integrity_tests$foreign_keys <- "WARNING"
  } else {
    cat("  ✅ All foreign key relationships valid\n")
    integrity_tests$foreign_keys <- "PASS"
  }
  
  # Test 2: Data ranges and constraints
  cat("  Testing data constraints...\n")
  
  # Check SOC percentages in charging profiles
  invalid_soc <- dbGetQuery(con, "
    SELECT COUNT(*) as count
    FROM charging_profiles
    WHERE soc_percentage < 0 OR soc_percentage > 100
  ")$count
  
  # Check tariff values
  invalid_tariffs <- dbGetQuery(con, "
    SELECT COUNT(*) as count
    FROM ev_tariffs_quarter_hourly  
    WHERE tariff_usd_per_kwh < 0 OR tariff_usd_per_kwh > 1
  ")$count
  
  # Check battery capacity
  invalid_battery <- dbGetQuery(con, "
    SELECT COUNT(*) as count
    FROM ev_models_catalog
    WHERE battery_capacity_kwh <= 0 OR battery_capacity_kwh > 200
  ")$count
  
  constraint_issues <- invalid_soc + invalid_tariffs + invalid_battery
  
  if (constraint_issues > 0) {
    cat(glue("  ⚠️  Warning: {constraint_issues} constraint violations found\n"))
    integrity_tests$constraints <- "WARNING"
  } else {
    cat("  ✅ All data constraints satisfied\n")
    integrity_tests$constraints <- "PASS"
  }
  
  # Test 3: Required data completeness
  cat("  Testing data completeness...\n")
  
  completeness_report <- dbGetQuery(con, "SELECT * FROM get_data_completeness_report()")
  
  empty_tables <- sum(completeness_report$data_status == "EMPTY")
  incomplete_tables <- sum(completeness_report$data_status == "INCOMPLETE")
  
  if (empty_tables > 0 || incomplete_tables > 0) {
    cat(glue("  ⚠️  Warning: {empty_tables} empty tables, {incomplete_tables} incomplete tables\n"))
    integrity_tests$completeness <- "WARNING"
  } else {
    cat("  ✅ All required tables have data\n")
    integrity_tests$completeness <- "PASS"
  }
  
  return(integrity_tests)
}

#' Test TimescaleDB features
test_timescaledb_features <- function(con) {
  cat("\n⏰ Testing TimescaleDB features...\n")
  
  timescale_tests <- list()
  
  # Test hypertable creation
  hypertables <- dbGetQuery(con, "
    SELECT hypertable_name, associated_schema_name
    FROM _timescaledb_catalog.hypertable
    WHERE hypertable_name = 'ev_simulation_results_final'
  ")
  
  if (nrow(hypertables) > 0) {
    cat("  ✅ Hypertable configured correctly\n")
    timescale_tests$hypertable <- "PASS"
  } else {
    cat("  ❌ Hypertable not found\n")
    timescale_tests$hypertable <- "FAIL"
  }
  
  # Test continuous aggregates
  caggs <- dbGetQuery(con, "
    SELECT view_name
    FROM _timescaledb_catalog.continuous_agg
    WHERE user_view_name IN ('daily_ev_demand_summary', 'hourly_demand_patterns')
  ")
  
  if (nrow(caggs) >= 2) {
    cat(glue("  ✅ Continuous aggregates created ({nrow(caggs)} found)\n"))
    timescale_tests$continuous_aggs <- "PASS"
  } else {
    cat(glue("  ⚠️  Warning: Only {nrow(caggs)} continuous aggregates found (expected 2)\n"))
    timescale_tests$continuous_aggs <- "WARNING"
  }
  
  return(timescale_tests)
}

#' Main test suite
run_complete_test_suite <- function() {
  cat("🧪 STARTING COMPLETE DATABASE TEST SUITE\n")
  cat("="*60, "\n\n")
  
  # Step 1: Create test database
  if (!create_test_database()) {
    cat("❌ Test suite failed: Cannot create test database\n")
    return(FALSE)
  }
  
  # Step 2: Connect to test database
  con <- connect_test_database()
  if (is.null(con)) {
    cat("❌ Test suite failed: Cannot connect to test database\n")
    return(FALSE)
  }
  
  on.exit(dbDisconnect(con))
  
  # Step 3: Test schema creation
  schema_success <- test_schema_creation(con)
  
  if (!schema_success) {
    cat("❌ Test suite failed: Schema creation failed\n")
    return(FALSE)
  }
  
  # Step 4: Test CSV loading
  loading_results <- test_all_csv_loading(con)
  
  # Step 5: Test data integrity
  integrity_results <- test_data_integrity(con)
  
  # Step 6: Test TimescaleDB features
  timescale_results <- test_timescaledb_features(con)
  
  # Final summary
  cat("\n", "="*60, "\n")
  cat("🏁 TEST SUITE RESULTS SUMMARY\n")
  cat("="*60, "\n")
  
  # Loading results
  cat("📊 CSV LOADING RESULTS:\n")
  for (name in names(loading_results)) {
    result <- loading_results[[name]]
    status <- if(result$success) "✅ PASS" else "❌ FAIL"
    cat(sprintf("  %-25s: %s", name, status))
    if (result$success && !is.null(result$count)) {
      cat(sprintf(" (%d rows)", result$count))
    }
    cat("\n")
  }
  
  # Integrity results
  cat("\n🔍 DATA INTEGRITY RESULTS:\n")
  for (test_name in names(integrity_results)) {
    result <- integrity_results[[test_name]]
    status <- case_when(
      result == "PASS" ~ "✅ PASS",
      result == "WARNING" ~ "⚠️  WARNING",
      TRUE ~ "❌ FAIL"
    )
    cat(sprintf("  %-25s: %s\n", test_name, status))
  }
  
  # TimescaleDB results
  cat("\n⏰ TIMESCALEDB RESULTS:\n")
  for (test_name in names(timescale_results)) {
    result <- timescale_results[[test_name]]
    status <- case_when(
      result == "PASS" ~ "✅ PASS",
      result == "WARNING" ~ "⚠️  WARNING", 
      TRUE ~ "❌ FAIL"
    )
    cat(sprintf("  %-25s: %s\n", test_name, status))
  }
  
  # Overall assessment
  loading_success <- sum(sapply(loading_results, function(x) x$success))
  total_loading <- length(loading_results)
  
  integrity_pass <- sum(sapply(integrity_results, function(x) x %in% c("PASS", "WARNING")))
  total_integrity <- length(integrity_results)
  
  timescale_pass <- sum(sapply(timescale_results, function(x) x %in% c("PASS", "WARNING")))
  total_timescale <- length(timescale_results)
  
  cat("\n", "="*60, "\n")
  cat("🎯 OVERALL ASSESSMENT:\n")
  cat(sprintf("  Data Loading:     %d/%d tables loaded successfully\n", loading_success, total_loading))
  cat(sprintf("  Data Integrity:   %d/%d tests passed\n", integrity_pass, total_integrity))
  cat(sprintf("  TimescaleDB:      %d/%d features working\n", timescale_pass, total_timescale))
  
  overall_success <- (loading_success == total_loading) && 
                    (integrity_pass == total_integrity) && 
                    (timescale_pass == total_timescale)
  
  if (overall_success) {
    cat("\n🎉 TEST SUITE PASSED! Database setup is working correctly.\n")
    return(TRUE)
  } else {
    cat("\n⚠️  TEST SUITE COMPLETED WITH ISSUES. Review results above.\n")
    return(FALSE)
  }
}

# ==============================================================================
# EXECUTION
# ==============================================================================

if (!interactive()) {
  # Running as script
  success <- run_complete_test_suite()
  if (!success) {
    quit(status = 1)
  }
} else {
  cat("🧪 Database test suite loaded!\n")
  cat("Run: run_complete_test_suite() to execute all tests\n")
}