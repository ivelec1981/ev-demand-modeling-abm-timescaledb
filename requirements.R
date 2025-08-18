# ==============================================================================
# requirements.R - R Package Dependencies for EV Demand Modeling Framework
# ==============================================================================
# 
# This script installs all required R packages for the EV demand modeling
# framework. Run this script before executing any simulations.
#
# Author: Iván Sánchez-Loor, Manuel Ayala-Chauvin
# Institution: Universidad Indoamérica - SISAu Research Group
# ==============================================================================

cat("🚀 Installing R dependencies for EV Demand Modeling Framework...\n")

# Configure CRAN mirror
options(repos = c(CRAN = "https://cran.rstudio.com/"))

# Core packages for data manipulation and analysis
core_packages <- c(
  "dplyr",           # Data manipulation
  "tidyr",           # Data tidying
  "purrr",           # Functional programming
  "readr",           # Data reading
  "lubridate",       # Date/time handling
  "stringr",         # String manipulation
  "forcats",         # Factor handling
  "tibble"           # Modern data frames
)

# Statistical and simulation packages
stats_packages <- c(
  "MASS",            # Statistical functions
  "mvtnorm",         # Multivariate normal distributions
  "truncnorm",       # Truncated normal distribution
  "fitdistrplus",    # Distribution fitting
  "moments",         # Statistical moments
  "forecast",        # Time series forecasting
  "tseries",         # Time series analysis
  "zoo"              # Time series objects
)

# Parallel processing and performance
parallel_packages <- c(
  "parallel",        # Base parallel processing
  "foreach",         # Parallel for loops
  "doParallel",      # Parallel backend
  "future",          # Unified parallel processing
  "future.apply",    # Apply functions with futures
  "furrr",           # Parallel purrr functions
  "progressr",       # Progress reporting
  "tictoc"           # Timing functions
)

# Database connectivity
database_packages <- c(
  "DBI",             # Database interface
  "RPostgreSQL",     # PostgreSQL driver
  "RPostgres",       # Modern PostgreSQL driver
  "pool",            # Connection pooling
  "dbplyr",          # Database backend for dplyr
  "config"           # Configuration management
)

# GPU acceleration (optional)
gpu_packages <- c(
  "GPUmatrix"        # GPU matrix operations
)

# Visualization and reporting
viz_packages <- c(
  "ggplot2",         # Grammar of graphics
  "plotly",          # Interactive plots
  "viridis",         # Color palettes
  "scales",          # Scale functions
  "gridExtra",       # Grid arrangements
  "knitr",           # Dynamic reporting
  "rmarkdown",       # R Markdown
  "htmlwidgets",     # HTML widgets
  "DT"               # Data tables
)

# Spatial analysis (if needed for geographic modeling)
spatial_packages <- c(
  "sf",              # Simple features
  "raster",          # Raster data
  "leaflet"          # Interactive maps
)

# Development and testing
dev_packages <- c(
  "devtools",        # Development tools
  "testthat",        # Unit testing
  "profvis",         # Profiling
  "bench",           # Benchmarking
  "microbenchmark"   # Micro-benchmarking
)

# Combine all packages
all_packages <- c(
  core_packages,
  stats_packages, 
  parallel_packages,
  database_packages,
  gpu_packages,
  viz_packages,
  spatial_packages,
  dev_packages
)

# Function to install packages safely
install_packages_safely <- function(packages) {
  cat(paste("📦 Installing", length(packages), "packages...\n"))
  
  # Check which packages are already installed
  installed <- installed.packages()[, "Package"]
  to_install <- packages[!packages %in% installed]
  
  if (length(to_install) == 0) {
    cat("✅ All packages already installed.\n")
    return(TRUE)
  }
  
  cat(paste("📥 Installing", length(to_install), "new packages...\n"))
  
  # Install packages with error handling
  success_count <- 0
  failed_packages <- character(0)
  
  for (pkg in to_install) {
    cat(paste("   Installing:", pkg, "..."))
    
    result <- tryCatch({
      install.packages(pkg, dependencies = TRUE, quiet = TRUE)
      cat(" ✅\n")
      success_count <- success_count + 1
      TRUE
    }, error = function(e) {
      cat(paste(" ❌ Error:", conditionMessage(e), "\n"))
      failed_packages <<- c(failed_packages, pkg)
      FALSE
    })
  }
  
  # Summary
  cat("\n📊 Installation Summary:\n")
  cat(paste("   ✅ Successful:", success_count, "/", length(to_install), "\n"))
  cat(paste("   ❌ Failed:", length(failed_packages), "\n"))
  
  if (length(failed_packages) > 0) {
    cat("\n⚠️  Failed packages:\n")
    for (pkg in failed_packages) {
      cat(paste("   -", pkg, "\n"))
    }
  }
  
  return(length(failed_packages) == 0)
}

# Function to verify installations
verify_installations <- function(packages) {
  cat("\n🧪 Verifying package installations...\n")
  
  success_count <- 0
  failed_packages <- character(0)
  
  for (pkg in packages) {
    result <- tryCatch({
      library(pkg, character.only = TRUE, quietly = TRUE)
      success_count <- success_count + 1
      TRUE
    }, error = function(e) {
      failed_packages <<- c(failed_packages, pkg)
      FALSE
    })
  }
  
  cat("📋 Verification Results:\n")
  cat(paste("   ✅ Working:", success_count, "/", length(packages), "\n"))
  cat(paste("   ❌ Issues:", length(failed_packages), "\n"))
  
  if (length(failed_packages) > 0) {
    cat("\n⚠️  Packages with loading issues:\n")
    for (pkg in failed_packages) {
      cat(paste("   -", pkg, "\n"))
    }
  }
  
  return(length(failed_packages) == 0)
}

# Function to check system requirements
check_system_requirements <- function() {
  cat("🔍 Checking system requirements...\n")
  
  # Check R version
  r_version <- R.Version()$version.string
  cat(paste("   R version:", r_version, "\n"))
  
  if (as.numeric(paste0(R.Version()$major, ".", R.Version()$minor)) < 4.3) {
    cat("   ⚠️  R version 4.3.0 or higher recommended\n")
  } else {
    cat("   ✅ R version compatible\n")
  }
  
  # Check available memory
  if (.Platform$OS.type == "unix") {
    memory_info <- system("free -h", intern = TRUE)
    cat("   Memory info:\n")
    cat(paste("   ", memory_info[2], "\n"))
  } else {
    cat("   💻 System: Windows\n")
  }
  
  # Check for GPU (optional)
  gpu_available <- tryCatch({
    suppressMessages(library(GPUmatrix, quietly = TRUE))
    TRUE
  }, error = function(e) {
    FALSE
  })
  
  if (gpu_available) {
    cat("   ✅ GPU acceleration available\n")
  } else {
    cat("   ℹ️  GPU acceleration not available (optional)\n")
  }
}

# Function to create configuration template
create_config_template <- function() {
  config_content <- '# Configuration template for EV Demand Modeling Framework
# Copy this to config.yml and modify as needed

default:
  database:
    host: "localhost"
    port: 5432
    dbname: "ev_simulation_db"
    user: "your_username"
    password: "your_password"
  
  simulation:
    default_vehicles: 10000
    default_days: 30
    time_resolution: 15  # minutes
    monte_carlo_runs: 1000
  
  processing:
    parallel_cores: 4
    memory_limit: "8GB"
    gpu_enabled: false
  
  output:
    save_to_db: true
    export_csv: true
    generate_plots: true
    output_dir: "results/"
'
  
  writeLines(config_content, "config_template.yml")
  cat("📝 Configuration template created: config_template.yml\n")
}

# Main execution
main <- function() {
  cat("═══════════════════════════════════════════════════════════════\n")
  cat("  EV Demand Modeling Framework - Dependency Installation\n")
  cat("═══════════════════════════════════════════════════════════════\n\n")
  
  # Check system requirements
  check_system_requirements()
  
  cat("\n" + paste(rep("─", 60), collapse = "") + "\n")
  
  # Install packages
  success <- install_packages_safely(all_packages)
  
  cat("\n" + paste(rep("─", 60), collapse = "") + "\n")
  
  # Verify installations
  verification_success <- verify_installations(all_packages)
  
  cat("\n" + paste(rep("─", 60), collapse = "") + "\n")
  
  # Create configuration template
  create_config_template()
  
  cat("\n" + paste(rep("═", 60), collapse = "") + "\n")
  
  # Final status
  if (success && verification_success) {
    cat("🎉 Installation completed successfully!\n")
    cat("✅ All dependencies are ready for EV demand modeling.\n")
    cat("\n📋 Next steps:\n")
    cat("   1. Configure database connection in config.yml\n")
    cat("   2. Run setup script: source('reproducibility/environment_setup.R')\n")
    cat("   3. Execute simulation: source('scripts/run_simulation.R')\n")
  } else {
    cat("⚠️  Installation completed with some issues.\n")
    cat("❌ Please review failed packages and try manual installation.\n")
  }
  
  cat("\n" + paste(rep("═", 60), collapse = "") + "\n")
}

# Execute if running as script
if (!interactive()) {
  main()
} else {
  cat("📌 Run main() to execute full installation process.\n")
  cat("📌 Individual package groups available as variables (e.g., core_packages)\n")
}

# Make functions available in global environment
.GlobalEnv$install_packages_safely <- install_packages_safely
.GlobalEnv$verify_installations <- verify_installations
.GlobalEnv$check_system_requirements <- check_system_requirements