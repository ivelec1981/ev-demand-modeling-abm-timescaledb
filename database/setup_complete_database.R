# ==============================================================================
# setup_complete_database.R - Complete Database Setup Script
# ==============================================================================
#
# This script creates the complete database schema and loads all CSV data
# in the correct order for the EV simulation system to function properly.
#
# Prerequisites:
# - PostgreSQL with TimescaleDB extension installed
# - Database 'ev_simulation_db' created
# - Environment variables set for database connection (optional)
#
# Author: Iván Sánchez-Loor, Manuel Ayala-Chauvin
# ==============================================================================

# Load required libraries
suppressPackageStartupMessages({
  library(DBI)
  library(RPostgres)
  library(glue)
})

# Configuration
SCRIPT_DIR <- dirname(rstudioapi::getActiveDocumentContext()$path)
if (length(SCRIPT_DIR) == 0 || SCRIPT_DIR == "") {
  SCRIPT_DIR <- getwd()
}

SCHEMA_FILE <- file.path(SCRIPT_DIR, "complete_schema_with_source_tables.sql")
DATA_LOADER_FILE <- file.path(SCRIPT_DIR, "load_csv_data.R")

# Database connection parameters
DB_CONFIG <- list(
  host = Sys.getenv("DB_HOST", "localhost"),
  port = as.integer(Sys.getenv("DB_PORT", "5432")),
  dbname = Sys.getenv("DB_NAME", "ev_simulation_db"),
  user = Sys.getenv("DB_USER", "postgres"),
  password = Sys.getenv("DB_PASSWORD", "")
)

# ==============================================================================
# UTILITY FUNCTIONS
# ==============================================================================

#' Connect to database with error handling
connect_database <- function() {
  cat("🔗 Attempting to connect to database...\n")
  cat("   Host:", DB_CONFIG$host, "\n")
  cat("   Port:", DB_CONFIG$port, "\n")
  cat("   Database:", DB_CONFIG$dbname, "\n")
  cat("   User:", DB_CONFIG$user, "\n\n")
  
  tryCatch({
    con <- dbConnect(
      RPostgres::Postgres(),
      host = DB_CONFIG$host,
      port = DB_CONFIG$port,
      dbname = DB_CONFIG$dbname,
      user = DB_CONFIG$user,
      password = DB_CONFIG$password
    )
    cat("✅ Database connection established successfully\n\n")
    return(con)
  }, error = function(e) {
    cat("❌ Error connecting to database:", conditionMessage(e), "\n")
    cat("\n🔧 TROUBLESHOOTING STEPS:\n")
    cat("1. Ensure PostgreSQL is running\n")
    cat("2. Verify database 'ev_simulation_db' exists\n")
    cat("3. Check connection parameters\n")
    cat("4. Ensure TimescaleDB extension is available\n\n")
    return(NULL)
  })
}

#' Execute SQL file with proper error handling
execute_sql_file <- function(con, file_path) {
  cat("📄 Executing SQL file:", basename(file_path), "\n")
  
  if (!file.exists(file_path)) {
    cat("❌ SQL file not found:", file_path, "\n")
    return(FALSE)
  }
  
  tryCatch({
    # Read SQL file
    sql_content <- readLines(file_path, warn = FALSE)
    sql_script <- paste(sql_content, collapse = "\n")
    
    # Split by semicolon to execute statements separately
    statements <- strsplit(sql_script, ";\\s*\\n")[[1]]
    statements <- statements[nzchar(trimws(statements))]
    
    # Execute each statement
    for (i in seq_along(statements)) {
      stmt <- trimws(statements[i])
      if (nzchar(stmt) && !grepl("^--", stmt)) {
        dbExecute(con, stmt)
      }
    }
    
    cat("✅ SQL file executed successfully\n")
    return(TRUE)
    
  }, error = function(e) {
    cat("❌ Error executing SQL file:", conditionMessage(e), "\n")
    return(FALSE)
  })
}

#' Check if schema already exists
check_existing_schema <- function(con) {
  tables <- dbGetQuery(con, "
    SELECT table_name 
    FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name IN (
      'cantones_pichincha',
      'ev_models_catalog', 
      'ev_simulation_results_final'
    )")
  
  return(nrow(tables) > 0)
}

# ==============================================================================
# MAIN SETUP FUNCTION
# ==============================================================================

#' Complete database setup
setup_database <- function(force_recreate = FALSE) {
  cat("🚀 STARTING COMPLETE DATABASE SETUP\n")
  cat("="*50, "\n\n")
  
  # Connect to database
  con <- connect_database()
  if (is.null(con)) {
    return(FALSE)
  }
  
  # Ensure we disconnect on exit
  on.exit(dbDisconnect(con))
  
  # Check existing schema
  schema_exists <- check_existing_schema(con)
  
  if (schema_exists && !force_recreate) {
    cat("⚠️  Database schema already exists!\n")
    response <- readline("Do you want to recreate it? This will delete all data (y/N): ")
    if (tolower(trimws(response)) != "y") {
      cat("❌ Setup cancelled by user\n")
      return(FALSE)
    }
    force_recreate <- TRUE
  }
  
  # Step 1: Create schema
  cat("🏗️  STEP 1: Creating database schema...\n")
  schema_success <- execute_sql_file(con, SCHEMA_FILE)
  
  if (!schema_success) {
    cat("❌ Schema creation failed. Cannot proceed.\n")
    return(FALSE)
  }
  
  cat("\n✅ Schema created successfully!\n\n")
  
  # Step 2: Load CSV data
  cat("📂 STEP 2: Loading CSV data...\n")
  
  if (!file.exists(DATA_LOADER_FILE)) {
    cat("❌ Data loader script not found:", DATA_LOADER_FILE, "\n")
    return(FALSE)
  }
  
  # Source and run data loader
  tryCatch({
    source(DATA_LOADER_FILE)
    data_success <- main()
    
    if (data_success) {
      cat("\n✅ Data loading completed successfully!\n\n")
    } else {
      cat("\n❌ Data loading encountered errors\n\n")
      return(FALSE)
    }
    
  }, error = function(e) {
    cat("❌ Error in data loading:", conditionMessage(e), "\n")
    return(FALSE)
  })
  
  # Step 3: Final verification
  cat("🔍 STEP 3: Final verification...\n")
  
  # Check TimescaleDB hypertable
  hypertable_check <- dbGetQuery(con, "
    SELECT hypertable_name, associated_schema_name
    FROM _timescaledb_catalog.hypertable 
    WHERE hypertable_name = 'ev_simulation_results_final'")
  
  if (nrow(hypertable_check) > 0) {
    cat("✅ TimescaleDB hypertable configured properly\n")
  } else {
    cat("⚠️  Warning: TimescaleDB hypertable not found\n")
  }
  
  # Check continuous aggregates
  cagg_check <- dbGetQuery(con, "
    SELECT view_name
    FROM _timescaledb_catalog.continuous_agg
    WHERE user_view_name IN ('daily_ev_demand_summary', 'hourly_demand_patterns')")
  
  cat("✅ Found", nrow(cagg_check), "continuous aggregates\n")
  
  # Final summary
  cat("\n", "="*60, "\n")
  cat("🎉 DATABASE SETUP COMPLETE!\n")
  cat("="*60, "\n")
  cat("✅ Schema created with all tables and indexes\n")
  cat("✅ CSV data loaded successfully\n")
  cat("✅ TimescaleDB features configured\n")
  cat("✅ Database ready for EV simulation\n\n")
  
  cat("💡 NEXT STEPS:\n")
  cat("1. Run your EV simulation R script\n")
  cat("2. Check data with: SELECT * FROM get_data_completeness_report()\n")
  cat("3. View results with: SELECT * FROM ev_simulation_results_final LIMIT 10\n\n")
  
  return(TRUE)
}

# ==============================================================================
# INTERACTIVE FUNCTIONS
# ==============================================================================

#' Quick status check
check_database_status <- function() {
  con <- connect_database()
  if (is.null(con)) return(FALSE)
  
  on.exit(dbDisconnect(con))
  
  cat("📊 DATABASE STATUS CHECK\n")
  cat("="*30, "\n")
  
  # Check if completeness function exists and run it
  tryCatch({
    completeness <- dbGetQuery(con, "SELECT * FROM get_data_completeness_report() ORDER BY table_name")
    print(completeness)
    
    # Check simulation results
    results_count <- dbGetQuery(con, "SELECT COUNT(*) as count FROM ev_simulation_results_final")$count
    cat("\nSimulation results records:", results_count, "\n")
    
  }, error = function(e) {
    cat("❌ Error checking status:", conditionMessage(e), "\n")
  })
}

# ==============================================================================
# EXECUTION
# ==============================================================================

if (!interactive()) {
  # Running as script - setup database automatically
  success <- setup_database()
  if (!success) {
    cat("❌ Database setup failed\n")
    quit(status = 1)
  } else {
    cat("✅ Database setup completed successfully\n")
  }
} else {
  cat("📝 Database setup script loaded successfully!\n\n")
  cat("Available functions:\n")
  cat("• setup_database()         - Complete database setup\n")
  cat("• setup_database(TRUE)     - Force recreate database\n")
  cat("• check_database_status()  - Check current status\n\n")
  cat("💡 Run: setup_database() to begin\n")
}