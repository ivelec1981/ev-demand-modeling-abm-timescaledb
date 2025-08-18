# ==============================================================================
# verify_csv_relationships.R - CSV Data Relationship Verification
# ==============================================================================
#
# This script verifies data relationships in CSV files BEFORE database loading
# to catch any integrity issues early in the process.
#
# Author: Iván Sánchez-Loor, Manuel Ayala-Chauvin
# ==============================================================================

# Load required libraries
suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(glue)
})

# Data directory
DATA_DIR <- "C:/Users/LEGION/Maestria BigData/Trabajo Titulacion/ev-demand-modeling-abm-timescaledb/database"

#' Load CSV with error handling
load_csv_safe <- function(file_name) {
  file_path <- file.path(DATA_DIR, file_name)
  
  if (!file.exists(file_path)) {
    cat("❌ File not found:", file_name, "\n")
    return(NULL)
  }
  
  tryCatch({
    if (file_name == "cantones_pichincha.csv") {
      # Handle semicolon delimiter
      data <- readr::read_delim(file_path, delim = ";", locale = locale(encoding = "UTF-8"))
    } else {
      data <- readr::read_csv(file_path, locale = locale(encoding = "UTF-8"))
    }
    
    cat("✅ Loaded", nrow(data), "rows from", file_name, "\n")
    return(data)
    
  }, error = function(e) {
    cat("❌ Error loading", file_name, ":", conditionMessage(e), "\n")
    return(NULL)
  })
}

#' Verify CSV data relationships
verify_csv_relationships <- function() {
  cat("🔍 VERIFYING CSV DATA RELATIONSHIPS\n")
  cat("="*50, "\n\n")
  
  # Load key data files
  cat("📂 Loading CSV files...\n")
  ev_models <- load_csv_safe("ev_models_catalog.csv")
  charging_profiles <- load_csv_safe("charging_profiles..csv")
  cantones <- load_csv_safe("cantones_pichincha.csv")
  tariffs <- load_csv_safe("ev_tariffs_quarter_hourly.csv")
  projections <- load_csv_safe("ev_provincial_projections.csv")
  
  if (any(sapply(list(ev_models, charging_profiles, cantones, tariffs), is.null))) {
    cat("❌ Critical files missing. Cannot verify relationships.\n")
    return(FALSE)
  }
  
  cat("\n🔗 Verifying relationships...\n")
  
  # 1. Charging profiles -> EV models relationship
  cat("  Checking charging_profiles -> ev_models_catalog...\n")
  
  unique_vehicle_ids_profiles <- unique(charging_profiles$vehicle_id)
  unique_vehicle_ids_models <- unique(ev_models$vehicle_model_id)
  
  orphaned_vehicles <- setdiff(unique_vehicle_ids_profiles, unique_vehicle_ids_models)
  
  if (length(orphaned_vehicles) == 0) {
    cat(glue("    ✅ All {length(unique_vehicle_ids_profiles)} vehicle IDs in profiles have matching models\n"))
  } else {
    cat(glue("    ❌ {length(orphaned_vehicles)} vehicle IDs in profiles have no matching models\n"))
    cat("    Missing vehicle IDs:", paste(orphaned_vehicles[1:min(10, length(orphaned_vehicles))], collapse = ", "), "\n")
    if (length(orphaned_vehicles) > 10) cat("    ... and", length(orphaned_vehicles) - 10, "more\n")
  }
  
  # 2. Data range validations
  cat("  Checking data ranges and constraints...\n")
  
  # SOC validation
  invalid_soc <- sum(charging_profiles$soc_percentage < 0 | charging_profiles$soc_percentage > 100, na.rm = TRUE)
  if (invalid_soc == 0) {
    cat("    ✅ All SOC values within valid range (0-100%)\n")
  } else {
    cat(glue("    ❌ {invalid_soc} charging profiles with invalid SOC values\n"))
  }
  
  # Battery capacity validation
  invalid_battery <- sum(ev_models$battery_capacity_kwh <= 0 | ev_models$battery_capacity_kwh > 300, na.rm = TRUE)
  if (invalid_battery == 0) {
    cat("    ✅ All battery capacities within reasonable range\n")
  } else {
    cat(glue("    ❌ {invalid_battery} EV models with unrealistic battery capacity\n"))
  }
  
  # Tariff validation
  invalid_tariffs <- sum(tariffs$tariff_usd_per_kwh < 0 | tariffs$tariff_usd_per_kwh > 1, na.rm = TRUE)
  if (invalid_tariffs == 0) {
    cat("    ✅ All tariff values within reasonable range\n")
  } else {
    cat(glue("    ❌ {invalid_tariffs} tariff entries with unrealistic values\n"))
  }
  
  # 3. Coverage analysis
  cat("  Checking data coverage...\n")
  
  # Tariff coverage (should have 96 quarter-hours × 2 day types = 192 entries)
  tariff_coverage <- tariffs %>%
    group_by(day_type) %>%
    summarise(quarters = n_distinct(quarter_hour_index), .groups = "drop")
  
  expected_quarters <- 96
  complete_coverage <- all(tariff_coverage$quarters >= expected_quarters)
  
  if (complete_coverage) {
    cat("    ✅ Complete tariff coverage for all time periods\n")
  } else {
    cat("    ⚠️  Incomplete tariff coverage:\n")
    for(i in 1:nrow(tariff_coverage)) {
      cat(glue("      {tariff_coverage$day_type[i]}: {tariff_coverage$quarters[i]}/{expected_quarters} quarters\n"))
    }
  }
  
  # 4. Geographic data validation
  if (!is.null(cantones)) {
    cat("  Checking geographic data...\n")
    
    # Clean coordinate data (remove formatting issues)
    cantones_clean <- cantones %>%
      mutate(
        lat_clean = as.numeric(gsub("([0-9.-]+)\\.000$", "\\1", latitude)),
        lon_clean = as.numeric(gsub("([0-9.-]+)\\.000$", "\\1", longitude))
      )
    
    # Ecuador coordinate bounds (approximate)
    invalid_coords <- sum(
      cantones_clean$lat_clean < -5 | cantones_clean$lat_clean > 2 |
      cantones_clean$lon_clean < -85 | cantones_clean$lon_clean > -75, 
      na.rm = TRUE
    )
    
    if (invalid_coords == 0) {
      cat("    ✅ All canton coordinates within Ecuador bounds\n")
    } else {
      cat(glue("    ❌ {invalid_coords} cantons with coordinates outside Ecuador\n"))
    }
  }
  
  # 5. Provincial projections validation
  if (!is.null(projections)) {
    cat("  Checking provincial projections...\n")
    
    pichincha_records <- sum(projections$province_name == "Pichincha", na.rm = TRUE)
    total_records <- nrow(projections)
    
    cat(glue("    ℹ️  {pichincha_records}/{total_records} projections are for Pichincha province\n"))
    
    if (pichincha_records > 0) {
      cat("    ✅ Pichincha projection data available\n")
    } else {
      cat("    ⚠️  No Pichincha projection data found\n")
    }
  }
  
  # Summary
  cat("\n", "="*50, "\n")
  cat("📋 VERIFICATION SUMMARY\n")
  cat("="*50, "\n")
  
  issues_found <- 0
  
  if (length(orphaned_vehicles) > 0) issues_found <- issues_found + 1
  if (invalid_soc > 0) issues_found <- issues_found + 1  
  if (invalid_battery > 0) issues_found <- issues_found + 1
  if (invalid_tariffs > 0) issues_found <- issues_found + 1
  if (!complete_coverage) issues_found <- issues_found + 1
  
  if (issues_found == 0) {
    cat("🎉 ALL VERIFICATIONS PASSED!\n")
    cat("CSV data is ready for database loading.\n\n")
    
    cat("📊 Data Statistics:\n")
    cat(glue("  • Cantons: {nrow(cantones)} records\n"))
    cat(glue("  • EV Models: {nrow(ev_models)} records\n"))  
    cat(glue("  • Charging Profiles: {nrow(charging_profiles)} records\n"))
    cat(glue("  • Tariff Entries: {nrow(tariffs)} records\n"))
    if (!is.null(projections)) cat(glue("  • Projections: {nrow(projections)} records\n"))
    
    cat("\n💡 Next Steps:\n")
    cat("  1. Run: source('setup_complete_database.R'); setup_database()\n")
    cat("  2. Validate: source('validate_data_integrity.R'); generate_validation_report()\n")
    
    return(TRUE)
    
  } else {
    cat(glue("⚠️  {issues_found} ISSUES FOUND\n"))
    cat("Please review and fix the issues above before database loading.\n")
    
    return(FALSE)
  }
}

# ==============================================================================
# EXECUTION
# ==============================================================================

if (!interactive()) {
  # Running as script
  success <- verify_csv_relationships()
  if (!success) {
    quit(status = 1)
  }
} else {
  cat("🔍 CSV relationship verification script loaded!\n")
  cat("Run: verify_csv_relationships() to check data integrity\n")
}