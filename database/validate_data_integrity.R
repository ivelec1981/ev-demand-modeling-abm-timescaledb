# ==============================================================================
# validate_data_integrity.R - Data Integrity and Relationship Validation
# ==============================================================================
#
# This script validates data integrity, foreign key relationships, and 
# ensures the database is ready for EV simulation operations.
#
# Author: Iván Sánchez-Loor, Manuel Ayala-Chauvin
# ==============================================================================

# Load required libraries
suppressPackageStartupMessages({
  library(DBI)
  library(RPostgres)
  library(dplyr)
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

# ==============================================================================
# VALIDATION FUNCTIONS
# ==============================================================================

#' Connect to database
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
    return(con)
  }, error = function(e) {
    cat("❌ Database connection failed:", conditionMessage(e), "\n")
    return(NULL)
  })
}

#' Validate foreign key relationships
validate_foreign_keys <- function(con) {
  cat("🔗 Validating foreign key relationships...\n")
  
  validation_results <- list()
  
  # 1. charging_profiles -> ev_models_catalog
  cat("  Checking charging_profiles -> ev_models_catalog...\n")
  orphaned_profiles <- dbGetQuery(con, "
    SELECT 
      COUNT(*) as orphaned_count,
      COUNT(DISTINCT cp.vehicle_id) as unique_orphaned_ids
    FROM charging_profiles cp
    LEFT JOIN ev_models_catalog emc ON cp.vehicle_id = emc.vehicle_model_id
    WHERE emc.vehicle_model_id IS NULL
  ")
  
  if (orphaned_profiles$orphaned_count > 0) {
    cat(glue("    ⚠️  {orphaned_profiles$orphaned_count} charging profiles with invalid vehicle_id\n"))
    cat(glue("    🔍 {orphaned_profiles$unique_orphaned_ids} unique invalid vehicle IDs\n"))
    
    # Show which vehicle IDs are problematic
    invalid_ids <- dbGetQuery(con, "
      SELECT DISTINCT cp.vehicle_id, COUNT(*) as profile_count
      FROM charging_profiles cp
      LEFT JOIN ev_models_catalog emc ON cp.vehicle_id = emc.vehicle_model_id
      WHERE emc.vehicle_model_id IS NULL
      GROUP BY cp.vehicle_id
      ORDER BY profile_count DESC
      LIMIT 10
    ")
    
    cat("    📋 Top invalid vehicle IDs:\n")
    for(i in 1:nrow(invalid_ids)) {
      cat(glue("      - Vehicle ID {invalid_ids$vehicle_id[i]}: {invalid_ids$profile_count[i]} profiles\n"))
    }
    
    validation_results$charging_profiles_fk <- "FAIL"
  } else {
    cat("    ✅ All charging profiles have valid vehicle IDs\n")
    validation_results$charging_profiles_fk <- "PASS"
  }
  
  # 2. ev_simulation_results_final -> cantones_pichincha (when data exists)
  cat("  Checking ev_simulation_results_final -> cantones_pichincha...\n")
  results_count <- dbGetQuery(con, "SELECT COUNT(*) as count FROM ev_simulation_results_final")$count
  
  if (results_count > 0) {
    orphaned_results <- dbGetQuery(con, "
      SELECT COUNT(*) as orphaned_count
      FROM ev_simulation_results_final esr
      LEFT JOIN cantones_pichincha cp ON esr.canton_id = cp.canton_id
      WHERE cp.canton_id IS NULL
    ")$orphaned_count
    
    if (orphaned_results > 0) {
      cat(glue("    ⚠️  {orphaned_results} simulation results with invalid canton_id\n"))
      validation_results$results_canton_fk <- "FAIL"
    } else {
      cat("    ✅ All simulation results have valid canton IDs\n")
      validation_results$results_canton_fk <- "PASS"
    }
  } else {
    cat("    ℹ️  No simulation results data to validate\n")
    validation_results$results_canton_fk <- "SKIP"
  }
  
  return(validation_results)
}

#' Validate data constraints and ranges
validate_data_constraints <- function(con) {
  cat("\n📏 Validating data constraints and ranges...\n")
  
  constraint_results <- list()
  
  # 1. State of Charge (SOC) validation
  cat("  Checking SOC percentages in charging profiles...\n")
  invalid_soc <- dbGetQuery(con, "
    SELECT 
      COUNT(*) as invalid_count,
      MIN(soc_percentage) as min_soc,
      MAX(soc_percentage) as max_soc
    FROM charging_profiles
    WHERE soc_percentage < 0 OR soc_percentage > 100
  ")
  
  if (invalid_soc$invalid_count > 0) {
    cat(glue("    ❌ {invalid_soc$invalid_count} profiles with invalid SOC\n"))
    cat(glue("    📊 SOC range: {invalid_soc$min_soc}% to {invalid_soc$max_soc}%\n"))
    constraint_results$soc_range <- "FAIL"
  } else {
    cat("    ✅ All SOC values are within valid range (0-100%)\n")
    constraint_results$soc_range <- "PASS"
  }
  
  # 2. Tariff validation
  cat("  Checking electricity tariff values...\n")
  tariff_stats <- dbGetQuery(con, "
    SELECT 
      COUNT(*) as invalid_count,
      MIN(tariff_usd_per_kwh) as min_tariff,
      MAX(tariff_usd_per_kwh) as max_tariff,
      AVG(tariff_usd_per_kwh) as avg_tariff
    FROM ev_tariffs_quarter_hourly
    WHERE tariff_usd_per_kwh < 0 OR tariff_usd_per_kwh > 1
  ")
  
  if (tariff_stats$invalid_count > 0) {
    cat(glue("    ❌ {tariff_stats$invalid_count} tariffs outside reasonable range\n"))
    constraint_results$tariff_range <- "FAIL"
  } else {
    cat(glue("    ✅ All tariffs reasonable (min: ${tariff_stats$min_tariff:.4f}, max: ${tariff_stats$max_tariff:.4f})\n"))
    constraint_results$tariff_range <- "PASS"
  }
  
  # 3. Battery capacity validation
  cat("  Checking EV battery capacities...\n")
  battery_stats <- dbGetQuery(con, "
    SELECT 
      COUNT(*) as invalid_count,
      MIN(battery_capacity_kwh) as min_capacity,
      MAX(battery_capacity_kwh) as max_capacity,
      AVG(battery_capacity_kwh) as avg_capacity
    FROM ev_models_catalog
    WHERE battery_capacity_kwh <= 0 OR battery_capacity_kwh > 300
  ")
  
  if (battery_stats$invalid_count > 0) {
    cat(glue("    ❌ {battery_stats$invalid_count} vehicles with unrealistic battery capacity\n"))
    constraint_results$battery_capacity <- "FAIL"
  } else {
    cat(glue("    ✅ All battery capacities reasonable ({battery_stats$min_capacity:.1f} - {battery_stats$max_capacity:.1f} kWh)\n"))
    constraint_results$battery_capacity <- "PASS"
  }
  
  # 4. Charging power validation
  cat("  Checking charging power ratings...\n")
  power_stats <- dbGetQuery(con, "
    SELECT 
      COUNT(*) as invalid_ac,
      MIN(max_ac_power_kw) as min_ac,
      MAX(max_ac_power_kw) as max_ac
    FROM ev_models_catalog
    WHERE max_ac_power_kw <= 0 OR max_ac_power_kw > 50
  ")
  
  dc_power_stats <- dbGetQuery(con, "
    SELECT 
      COUNT(*) as invalid_dc,
      MIN(max_dc_power_kw) as min_dc,
      MAX(max_dc_power_kw) as max_dc
    FROM ev_models_catalog
    WHERE max_dc_power_kw IS NOT NULL AND (max_dc_power_kw <= 0 OR max_dc_power_kw > 500)
  ")
  
  power_issues <- power_stats$invalid_ac + dc_power_stats$invalid_dc
  
  if (power_issues > 0) {
    cat(glue("    ❌ {power_issues} vehicles with invalid charging power\n"))
    constraint_results$charging_power <- "FAIL"
  } else {
    cat(glue("    ✅ All charging powers reasonable (AC: {power_stats$min_ac}-{power_stats$max_ac} kW)\n"))
    constraint_results$charging_power <- "PASS"
  }
  
  # 5. Geographic coordinates validation
  cat("  Checking geographic coordinates...\n")
  coord_stats <- dbGetQuery(con, "
    SELECT 
      COUNT(*) as invalid_count,
      MIN(latitude) as min_lat,
      MAX(latitude) as max_lat,
      MIN(longitude) as min_lon,
      MAX(longitude) as max_lon
    FROM cantones_pichincha
    WHERE latitude < -5 OR latitude > 2 OR longitude < -85 OR longitude > -75
  ")
  
  if (coord_stats$invalid_count > 0) {
    cat(glue("    ❌ {coord_stats$invalid_count} cantons with invalid coordinates for Ecuador\n"))
    constraint_results$coordinates <- "FAIL"
  } else {
    cat(glue("    ✅ All coordinates within Ecuador bounds\n"))
    constraint_results$coordinates <- "PASS"
  }
  
  return(constraint_results)
}

#' Validate data completeness
validate_data_completeness <- function(con) {
  cat("\n📊 Validating data completeness...\n")
  
  completeness_results <- list()
  
  # Use the built-in completeness report function
  tryCatch({
    completeness <- dbGetQuery(con, "SELECT * FROM get_data_completeness_report()")
    
    cat("  📋 Data completeness report:\n")
    for(i in 1:nrow(completeness)) {
      status_icon <- case_when(
        completeness$data_status[i] == "OK" ~ "✅",
        completeness$data_status[i] == "INCOMPLETE" ~ "⚠️",
        TRUE ~ "❌"
      )
      
      cat(glue("    {status_icon} {completeness$table_name[i]}: {completeness$record_count[i]} records ({completeness$data_status[i]})\n"))
    }
    
    # Summary metrics
    empty_tables <- sum(completeness$data_status == "EMPTY")
    incomplete_tables <- sum(completeness$data_status == "INCOMPLETE")
    ok_tables <- sum(completeness$data_status == "OK")
    
    cat("\n  📈 Summary:\n")
    cat(glue("    ✅ OK: {ok_tables} tables\n"))
    cat(glue("    ⚠️  Incomplete: {incomplete_tables} tables\n"))
    cat(glue("    ❌ Empty: {empty_tables} tables\n"))
    
    if (empty_tables == 0 && incomplete_tables == 0) {
      completeness_results$overall <- "PASS"
    } else if (empty_tables > 0) {
      completeness_results$overall <- "FAIL"
    } else {
      completeness_results$overall <- "WARNING"
    }
    
  }, error = function(e) {
    cat("  ❌ Error running completeness report:", conditionMessage(e), "\n")
    completeness_results$overall <- "ERROR"
  })
  
  return(completeness_results)
}

#' Validate critical simulation requirements
validate_simulation_readiness <- function(con) {
  cat("\n🎯 Validating simulation readiness...\n")
  
  readiness_results <- list()
  
  # 1. Check minimum required data for simulation
  cat("  Checking minimum required data...\n")
  
  required_checks <- list(
    cantones = "SELECT COUNT(*) FROM cantones_pichincha",
    ev_models = "SELECT COUNT(*) FROM ev_models_catalog", 
    tariffs = "SELECT COUNT(*) FROM ev_tariffs_quarter_hourly",
    charging_profiles = "SELECT COUNT(*) FROM charging_profiles WHERE soc_percentage <= 100",
    charging_patterns = "SELECT COUNT(*) FROM ev_charging_patterns_15min"
  )
  
  for (check_name in names(required_checks)) {
    count <- dbGetQuery(con, required_checks[[check_name]])[[1]]
    
    min_required <- case_when(
      check_name == "cantones" ~ 1,
      check_name == "ev_models" ~ 1,
      check_name == "tariffs" ~ 96,  # At least 96 quarter-hours
      check_name == "charging_profiles" ~ 10,  # At least some profiles
      check_name == "charging_patterns" ~ 96,  # 96 quarter-hour patterns
      TRUE ~ 1
    )
    
    if (count >= min_required) {
      cat(glue("    ✅ {check_name}: {count} records (>= {min_required} required)\n"))
      readiness_results[[check_name]] <- "PASS"
    } else {
      cat(glue("    ❌ {check_name}: {count} records (< {min_required} required)\n"))
      readiness_results[[check_name]] <- "FAIL"
    }
  }
  
  # 2. Check for complete tariff coverage (weekday/weekend × 96 quarters)
  cat("  Checking tariff coverage...\n")
  tariff_coverage <- dbGetQuery(con, "
    SELECT 
      day_type,
      COUNT(*) as quarters_covered,
      MIN(quarter_hour_index) as min_quarter,
      MAX(quarter_hour_index) as max_quarter
    FROM ev_tariffs_quarter_hourly
    GROUP BY day_type
  ")
  
  expected_quarters <- 96
  complete_coverage <- all(tariff_coverage$quarters_covered >= expected_quarters)
  
  if (complete_coverage) {
    cat("    ✅ Complete tariff coverage for all time periods\n")
    readiness_results$tariff_coverage <- "PASS"
  } else {
    cat("    ❌ Incomplete tariff coverage\n")
    for(i in 1:nrow(tariff_coverage)) {
      cat(glue("      {tariff_coverage$day_type[i]}: {tariff_coverage$quarters_covered[i]}/{expected_quarters} quarters\n"))
    }
    readiness_results$tariff_coverage <- "FAIL"
  }
  
  # 3. Check TimescaleDB readiness
  cat("  Checking TimescaleDB configuration...\n")
  
  hypertable_check <- dbGetQuery(con, "
    SELECT COUNT(*) as count
    FROM _timescaledb_catalog.hypertable 
    WHERE hypertable_name = 'ev_simulation_results_final'
  ")$count
  
  if (hypertable_check > 0) {
    cat("    ✅ TimescaleDB hypertable configured\n")
    readiness_results$timescaledb <- "PASS"
  } else {
    cat("    ⚠️  TimescaleDB hypertable not found (will impact performance)\n")
    readiness_results$timescaledb <- "WARNING"
  }
  
  return(readiness_results)
}

#' Generate comprehensive validation report
generate_validation_report <- function() {
  cat("🔍 COMPREHENSIVE DATA VALIDATION REPORT\n")
  cat("="*60, "\n\n")
  
  con <- connect_database()
  if (is.null(con)) {
    cat("❌ Cannot connect to database. Validation aborted.\n")
    return(FALSE)
  }
  
  on.exit(dbDisconnect(con))
  
  # Run all validations
  fk_results <- validate_foreign_keys(con)
  constraint_results <- validate_data_constraints(con)
  completeness_results <- validate_data_completeness(con)
  readiness_results <- validate_simulation_readiness(con)
  
  # Summary report
  cat("\n", "="*60, "\n")
  cat("📋 VALIDATION SUMMARY\n")
  cat("="*60, "\n")
  
  all_results <- c(fk_results, constraint_results, completeness_results, readiness_results)
  
  pass_count <- sum(sapply(all_results, function(x) x == "PASS"))
  warning_count <- sum(sapply(all_results, function(x) x == "WARNING"))
  fail_count <- sum(sapply(all_results, function(x) x == "FAIL"))
  skip_count <- sum(sapply(all_results, function(x) x == "SKIP"))
  total_checks <- length(all_results)
  
  cat(glue("✅ PASSED:   {pass_count} checks\n"))
  cat(glue("⚠️  WARNING:  {warning_count} checks\n"))
  cat(glue("❌ FAILED:   {fail_count} checks\n"))
  cat(glue("⏭️  SKIPPED:  {skip_count} checks\n"))
  cat(glue("📊 TOTAL:    {total_checks} checks\n\n"))
  
  # Overall assessment
  if (fail_count == 0 && warning_count <= 2) {
    cat("🎉 OVERALL ASSESSMENT: DATABASE READY FOR SIMULATION\n")
    cat("All critical validations passed. The database is properly configured.\n")
    return(TRUE)
  } else if (fail_count == 0) {
    cat("⚠️  OVERALL ASSESSMENT: DATABASE MOSTLY READY (WARNINGS)\n")
    cat("Database is functional but has some warnings that should be addressed.\n")
    return(TRUE)
  } else {
    cat("❌ OVERALL ASSESSMENT: DATABASE NOT READY\n")
    cat(glue("Database has {fail_count} critical issues that must be fixed before simulation.\n"))
    return(FALSE)
  }
}

# ==============================================================================
# EXECUTION
# ==============================================================================

if (!interactive()) {
  # Running as script
  success <- generate_validation_report()
  if (!success) {
    cat("\n💡 NEXT STEPS:\n")
    cat("1. Review validation errors above\n")
    cat("2. Fix data issues or schema mismatches\n") 
    cat("3. Re-run validation: Rscript validate_data_integrity.R\n")
    quit(status = 1)
  }
} else {
  cat("🔍 Data validation script loaded!\n")
  cat("Run: generate_validation_report() to validate database\n")
}