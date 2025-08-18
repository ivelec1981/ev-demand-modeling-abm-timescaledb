# ==============================================================================
# validate_installation.R - Installation Validation Script
# ==============================================================================
#
# This script validates that all components of the EV demand modeling framework
# are properly installed and configured.
#
# Author: Iván Sánchez-Loor, Manuel Ayala-Chauvin
# ==============================================================================

cat("🔍 VALIDATING EV DEMAND MODELING INSTALLATION\n")
cat("============================================\n\n")

# Track validation results
validation_results <- list()
has_errors <- FALSE

# Helper function to check and report
check_component <- function(name, condition, details = "") {
  if (condition) {
    cat(sprintf("✅ %s\n", name))
    if (details != "") cat(sprintf("   %s\n", details))
    validation_results[[name]] <<- list(status = "OK", details = details)
  } else {
    cat(sprintf("❌ %s\n", name))
    if (details != "") cat(sprintf("   %s\n", details))
    validation_results[[name]] <<- list(status = "FAILED", details = details)
    has_errors <<- TRUE
  }
}

# 1. R VERSION AND BASIC PACKAGES
cat("1️⃣ Checking R Environment...\n")

r_version <- R.version.string
check_component(
  "R Version", 
  as.numeric(R.version$major) >= 4,
  sprintf("Found: %s (Required: 4.0+)", r_version)
)

# Check base packages
base_packages <- c("stats", "utils", "parallel")
for (pkg in base_packages) {
  check_component(
    sprintf("Base package: %s", pkg),
    require(pkg, quietly = TRUE, character.only = TRUE),
    sprintf("Package %s loaded successfully", pkg)
  )
}

# 2. REQUIRED R PACKAGES
cat("\n2️⃣ Checking Required R Packages...\n")

required_packages <- list(
  "dplyr" = "Data manipulation",
  "lubridate" = "Date/time handling", 
  "readr" = "File reading",
  "jsonlite" = "JSON processing",
  "future" = "Parallel processing",
  "DBI" = "Database interface",
  "RPostgres" = "PostgreSQL connector"
)

for (pkg_name in names(required_packages)) {
  pkg_desc <- required_packages[[pkg_name]]
  is_available <- require(pkg_name, quietly = TRUE, character.only = TRUE)
  
  if (is_available) {
    pkg_version <- as.character(packageVersion(pkg_name))
    check_component(
      sprintf("Package: %s", pkg_name),
      TRUE,
      sprintf("%s v%s", pkg_desc, pkg_version)
    )
  } else {
    check_component(
      sprintf("Package: %s", pkg_name),
      FALSE,
      sprintf("Missing: %s", pkg_desc)
    )
  }
}

# 3. OPTIONAL PERFORMANCE PACKAGES
cat("\n3️⃣ Checking Performance Packages...\n")

optional_packages <- list(
  "GPUmatrix" = "GPU acceleration (optional)",
  "furrr" = "Enhanced parallel processing",
  "data.table" = "Fast data manipulation",
  "Rcpp" = "C++ integration"
)

for (pkg_name in names(optional_packages)) {
  pkg_desc <- optional_packages[[pkg_name]]
  is_available <- require(pkg_name, quietly = TRUE, character.only = TRUE)
  
  if (is_available) {
    cat(sprintf("✅ Optional: %s\n", pkg_name))
    cat(sprintf("   %s available\n", pkg_desc))
  } else {
    cat(sprintf("⚠️  Optional: %s\n", pkg_name))
    cat(sprintf("   %s not available (install for better performance)\n", pkg_desc))
  }
}

# 4. PROJECT STRUCTURE
cat("\n4️⃣ Checking Project Structure...\n")

required_dirs <- c("src", "data", "database", "scripts")
for (dir_name in required_dirs) {
  check_component(
    sprintf("Directory: %s/", dir_name),
    dir.exists(dir_name),
    sprintf("Required directory %s exists", dir_name)
  )
}

required_files <- list(
  "src/ev_simulator_final.R" = "Main simulation engine",
  "src/real_data_loader.R" = "Real data loader",
  "database/schema.sql" = "Database schema",
  "requirements.R" = "Package installer",
  "README.md" = "Project documentation"
)

for (file_path in names(required_files)) {
  file_desc <- required_files[[file_path]]
  check_component(
    sprintf("File: %s", file_path),
    file.exists(file_path),
    file_desc
  )
}

# 5. DATA AVAILABILITY
cat("\n5️⃣ Checking Data Availability...\n")

# Check for real EEQ data (internal)
internal_data_path <- "data/raw/eeq_profiles"
internal_data_files <- if (dir.exists(internal_data_path)) {
  list.files(internal_data_path, pattern = "*.csv", recursive = TRUE)
} else {
  character(0)
}

check_component(
  "Internal EEQ data",
  length(internal_data_files) > 0,
  sprintf("Found %d CSV files in %s", length(internal_data_files), internal_data_path)
)

# Check for external EEQ data
external_data_path <- "C:/Users/LEGION/Maestria BigData/Trabajo Titulacion/EEQ/ConsolidadoPerfiles"
external_data_files <- if (dir.exists(external_data_path)) {
  list.files(external_data_path, pattern = "*.csv", recursive = TRUE)
} else {
  character(0)
}

check_component(
  "External EEQ data",
  length(external_data_files) > 0,
  sprintf("Found %d CSV files in external location", length(external_data_files))
)

# Check for synthetic fallback data
fallback_data_path <- "data/fallback_data"
has_fallback <- dir.exists(fallback_data_path) && 
                length(list.files(fallback_data_path)) > 0

check_component(
  "Fallback synthetic data",
  has_fallback,
  "Synthetic data available for testing"
)

# 6. SIMULATION MODULES
cat("\n6️⃣ Testing Simulation Modules...\n")

# Test loading main simulation module
tryCatch({
  source("src/ev_simulator_final.R")
  check_component(
    "Main simulation module",
    exists("run_final_simulation"),
    "ev_simulator_final.R loaded successfully"
  )
  
  # Test getting default configuration
  if (exists("get_default_config")) {
    config <- get_default_config()
    check_component(
      "Default configuration",
      is.list(config) && length(config) > 0,
      sprintf("Configuration has %d sections", length(config))
    )
  }
  
}, error = function(e) {
  check_component(
    "Main simulation module",
    FALSE,
    sprintf("Error loading: %s", e$message)
  )
})

# Test real data loader
tryCatch({
  source("src/real_data_loader.R")
  check_component(
    "Real data loader module",
    exists("load_eeq_consumption_profiles"),
    "real_data_loader.R loaded successfully"
  )
}, error = function(e) {
  check_component(
    "Real data loader module",
    FALSE,
    sprintf("Error loading: %s", e$message)
  )
})

# 7. SYSTEM RESOURCES
cat("\n7️⃣ Checking System Resources...\n")

# Memory check
memory_info <- memory.size()  # Windows-specific
check_component(
  "Available memory",
  memory_info > 512,  # MB
  sprintf("%.1f MB available (recommended: 2GB+)", memory_info)
)

# CPU cores
num_cores <- parallel::detectCores()
check_component(
  "CPU cores",
  num_cores >= 2,
  sprintf("%d cores detected", num_cores)
)

# 8. DATABASE CONNECTIVITY (OPTIONAL)
cat("\n8️⃣ Testing Database Connectivity (Optional)...\n")

# Test PostgreSQL/TimescaleDB connection
db_available <- FALSE
tryCatch({
  if (require(DBI, quietly = TRUE) && require(RPostgres, quietly = TRUE)) {
    # Try to connect with default parameters
    con <- DBI::dbConnect(
      RPostgres::Postgres(),
      host = "localhost",
      port = 5432,
      dbname = "ev_simulation_db",
      user = "ev_user",
      password = "your_secure_password"
    )
    
    # Test basic query
    result <- DBI::dbGetQuery(con, "SELECT version();")
    DBI::dbDisconnect(con)
    db_available <- TRUE
    
    cat("✅ Database connection\n")
    cat("   TimescaleDB/PostgreSQL accessible\n")
  }
}, error = function(e) {
  cat("⚠️  Database connection\n")
  cat(sprintf("   Cannot connect to database: %s\n", e$message))
  cat("   Database features will be disabled\n")
})

# 9. GENERATE VALIDATION REPORT
cat("\n" + paste(rep("=", 60), collapse = "") + "\n")
cat("📊 VALIDATION SUMMARY\n")
cat(paste(rep("=", 60), collapse = "") + "\n")

# Count results
total_checks <- length(validation_results)
passed_checks <- sum(sapply(validation_results, function(x) x$status == "OK"))
failed_checks <- total_checks - passed_checks

cat(sprintf("\n✅ Passed: %d/%d checks\n", passed_checks, total_checks))
if (failed_checks > 0) {
  cat(sprintf("❌ Failed: %d/%d checks\n", failed_checks, total_checks))
}

# Overall status
if (!has_errors) {
  cat("\n🎉 INSTALLATION VALIDATED SUCCESSFULLY!\n")
  cat("   All required components are properly installed.\n")
  cat("   You can proceed with simulations.\n")
  
  cat("\n🚀 QUICK START:\n")
  cat("   1. Run: source('ejecutar_con_datos_reales.R')\n")
  cat("   2. Or use: bash scripts/run_simulation.sh\n")
  cat("   3. Check results in results/ directory\n")
  
} else {
  cat("\n⚠️  INSTALLATION HAS ISSUES!\n")
  cat("   Some required components are missing or misconfigured.\n")
  cat("   Please address the failed checks above.\n")
  
  cat("\n🔧 RECOMMENDED ACTIONS:\n")
  cat("   1. Run: Rscript requirements.R\n")
  cat("   2. Run: Rscript setup_project_data.R\n")
  cat("   3. Check database setup instructions\n")
}

# Save validation report
validation_timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
report_file <- sprintf("validation_report_%s.json", validation_timestamp)

report_data <- list(
  timestamp = Sys.time(),
  r_version = r_version,
  total_checks = total_checks,
  passed_checks = passed_checks,
  failed_checks = failed_checks,
  overall_status = if (has_errors) "FAILED" else "PASSED",
  detailed_results = validation_results,
  system_info = list(
    platform = R.version$platform,
    os = Sys.info()["sysname"],
    memory_mb = memory_info,
    cpu_cores = num_cores
  )
)

tryCatch({
  writeLines(jsonlite::toJSON(report_data, pretty = TRUE, auto_unbox = TRUE), report_file)
  cat(sprintf("\n📄 Validation report saved: %s\n", report_file))
}, error = function(e) {
  warning(sprintf("Could not save validation report: %s", e$message))
})

cat(paste(rep("=", 60), collapse = ""), "\n")

# Return exit code based on validation results
if (has_errors) {
  quit(status = 1)
} else {
  quit(status = 0)
}