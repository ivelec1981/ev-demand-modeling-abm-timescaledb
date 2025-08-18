#!/bin/bash
# ==============================================================================
# run_simulation.sh - Main Simulation Execution Script
# ==============================================================================
#
# This script executes the EV demand modeling simulation with various
# configurations and processing modes.
#
# Author: Iván Sánchez-Loor, Manuel Ayala-Chauvin
# ==============================================================================

set -e  # Exit on any error

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_DIR/logs"
RESULTS_DIR="$PROJECT_DIR/results"

# Create directories
mkdir -p "$LOG_DIR" "$RESULTS_DIR"

# Function to print colored output
print_status() {
    echo -e "\e[32m[$(date '+%Y-%m-%d %H:%M:%S')] $1\e[0m"
}

print_error() {
    echo -e "\e[31m[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1\e[0m"
}

print_warning() {
    echo -e "\e[33m[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1\e[0m"
}

# Help function
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Options:
    -m, --mode MODE          Processing mode: CPU, GPU, AUTO (default: AUTO)
    -v, --vehicles N         Number of vehicles to simulate (default: 1000)
    -d, --days N             Number of days to simulate (default: 7)
    -r, --runs N             Monte Carlo runs (default: 100)
    -c, --config FILE        Custom configuration file
    -o, --output DIR         Output directory (default: ./results)
    -l, --log-level LEVEL    Log level: DEBUG, INFO, WARN, ERROR (default: INFO)
    --use-real-data          Use real EEQ data for calibration
    --save-to-db            Save results to TimescaleDB
    --generate-plots        Generate visualization plots
    --validate              Run validation against real data
    -h, --help              Show this help message

Examples:
    # Basic simulation with default settings
    $0

    # Large simulation with GPU acceleration
    $0 --mode GPU --vehicles 50000 --days 30 --runs 1000

    # Simulation with real EEQ data
    $0 --use-real-data --validate --generate-plots

    # Custom configuration
    $0 --config configs/production.json --save-to-db
EOF
}

# Parse command line arguments
MODE="AUTO"
VEHICLES=1000
DAYS=7
RUNS=100
CONFIG_FILE=""
OUTPUT_DIR="$RESULTS_DIR"
LOG_LEVEL="INFO"
USE_REAL_DATA=false
SAVE_TO_DB=false
GENERATE_PLOTS=false
VALIDATE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -m|--mode)
            MODE="$2"
            shift 2
            ;;
        -v|--vehicles)
            VEHICLES="$2"
            shift 2
            ;;
        -d|--days)
            DAYS="$2"
            shift 2
            ;;
        -r|--runs)
            RUNS="$2"
            shift 2
            ;;
        -c|--config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -l|--log-level)
            LOG_LEVEL="$2"
            shift 2
            ;;
        --use-real-data)
            USE_REAL_DATA=true
            shift
            ;;
        --save-to-db)
            SAVE_TO_DB=true
            shift
            ;;
        --generate-plots)
            GENERATE_PLOTS=true
            shift
            ;;
        --validate)
            VALIDATE=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Validate processing mode
if [[ ! "$MODE" =~ ^(CPU|GPU|AUTO)$ ]]; then
    print_error "Invalid processing mode: $MODE. Must be CPU, GPU, or AUTO."
    exit 1
fi

# Check R installation
if ! command -v R &> /dev/null; then
    print_error "R is not installed or not in PATH"
    exit 1
fi

# Check if required R packages are installed
print_status "Checking R dependencies..."
R --slave --quiet -e "
if (!require('dplyr', quietly = TRUE)) quit('no', 1)
if (!require('lubridate', quietly = TRUE)) quit('no', 1)
if (!require('parallel', quietly = TRUE)) quit('no', 1)
" 2>/dev/null || {
    print_error "Required R packages are missing. Run: Rscript requirements.R"
    exit 1
}

# Create timestamp for this run
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
RUN_ID="simulation_${TIMESTAMP}"
LOG_FILE="$LOG_DIR/${RUN_ID}.log"

print_status "Starting EV Demand Modeling Simulation"
print_status "Run ID: $RUN_ID"
print_status "Log file: $LOG_FILE"

# Log all parameters
{
    echo "=== EV DEMAND MODELING SIMULATION ==="
    echo "Start Time: $(date)"
    echo "Run ID: $RUN_ID"
    echo "Processing Mode: $MODE"
    echo "Vehicles: $VEHICLES"
    echo "Days: $DAYS"
    echo "Monte Carlo Runs: $RUNS"
    echo "Use Real Data: $USE_REAL_DATA"
    echo "Save to DB: $SAVE_TO_DB"
    echo "Generate Plots: $GENERATE_PLOTS"
    echo "Validate: $VALIDATE"
    echo "Output Directory: $OUTPUT_DIR"
    echo "===================================="
} > "$LOG_FILE"

# Change to project directory
cd "$PROJECT_DIR"

# Create R script for this simulation
R_SCRIPT="scripts/temp_simulation_${TIMESTAMP}.R"
cat > "$R_SCRIPT" << EOF
# Temporary simulation script
# Generated: $(date)

# Set working directory
setwd("$PROJECT_DIR")

# Load main simulation modules
source("src/ev_simulator_final.R")
if ($USE_REAL_DATA) {
    source("src/real_data_loader.R")
}

# Configuration
config <- get_default_config()
config\$vehicles\$num_vehicles <- $VEHICLES
config\$simulation\$days <- $DAYS
config\$simulation\$monte_carlo_runs <- $RUNS

if ("$CONFIG_FILE" != "") {
    if (file.exists("$CONFIG_FILE")) {
        custom_config <- jsonlite::fromJSON("$CONFIG_FILE")
        config <- modifyList(config, custom_config)
        cat("✅ Loaded custom configuration from $CONFIG_FILE\n")
    } else {
        warning("Custom config file not found: $CONFIG_FILE")
    }
}

cat("🚀 Starting simulation with configuration:\n")
cat(sprintf("   🚗 Vehicles: %d\n", config\$vehicles\$num_vehicles))
cat(sprintf("   📅 Days: %d\n", config\$simulation\$days))
cat(sprintf("   🎲 Monte Carlo runs: %d\n", config\$simulation\$monte_carlo_runs))

# Calibrate with real data if requested
if ($USE_REAL_DATA) {
    cat("📊 Loading and calibrating with real EEQ data...\n")
    
    # Try project data first, then external data
    if (dir.exists("data/raw/eeq_profiles") && length(list.files("data/raw/eeq_profiles", pattern = "*.csv", recursive = TRUE)) > 0) {
        eeq_data <- load_eeq_consumption_profiles("data/raw/eeq_profiles", limit_files = 50)
    } else {
        eeq_data <- load_eeq_consumption_profiles(limit_files = 50)
    }
    
    if (nrow(eeq_data) > 0) {
        config <- calibrate_with_real_data(eeq_data, config)
        cat("✅ Configuration calibrated with real data\n")
    } else {
        warning("No real data available, using default configuration")
    }
}

# Execute simulation
cat("⚡ Executing simulation...\n")
start_time <- Sys.time()

results <- run_final_simulation(
    config = config,
    processing_engine = "$MODE",
    save_to_db = $SAVE_TO_DB,
    verbose = TRUE
)

end_time <- Sys.time()
duration <- as.numeric(end_time - start_time, units = "mins")

cat(sprintf("✅ Simulation completed in %.2f minutes\n", duration))

# Validation against real data
if ($VALIDATE && $USE_REAL_DATA && exists("eeq_data") && nrow(eeq_data) > 0) {
    cat("🔍 Validating against real data...\n")
    validation_metrics <- validate_simulation_against_real_data(results, eeq_data)
    cat(sprintf("📊 Validation MAPE: %.2f%%\n", validation_metrics\$mape))
    cat(sprintf("🔗 Correlation: %.3f\n", validation_metrics\$correlation))
}

# Save results
output_dir <- "$OUTPUT_DIR"
if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
}

# Save comprehensive results
results_file <- file.path(output_dir, "${RUN_ID}_results.rds")
saveRDS(results, results_file)

# Create summary
summary_data <- list(
    run_id = "$RUN_ID",
    timestamp = Sys.time(),
    configuration = config,
    simulation_results = results\$summary,
    validation_metrics = if (exists("validation_metrics")) validation_metrics else NULL,
    duration_minutes = duration,
    processing_mode = "$MODE"
)

summary_file <- file.path(output_dir, "${RUN_ID}_summary.json")
writeLines(jsonlite::toJSON(summary_data, pretty = TRUE, auto_unbox = TRUE), summary_file)

# Generate CSV summary
csv_summary <- data.frame(
    run_id = "$RUN_ID",
    timestamp = as.character(Sys.time()),
    vehicles = config\$vehicles\$num_vehicles,
    days = config\$simulation\$days,
    monte_carlo_runs = config\$simulation\$monte_carlo_runs,
    processing_mode = "$MODE",
    mean_demand_kw = results\$summary\$mean_daily_demand,
    peak_demand_kw = results\$summary\$peak_demand,
    load_factor = results\$summary\$load_factor,
    duration_minutes = duration,
    validation_mape = if (exists("validation_metrics")) validation_metrics\$mape else NA,
    validation_correlation = if (exists("validation_metrics")) validation_metrics\$correlation else NA
)

csv_file <- file.path(output_dir, "${RUN_ID}_summary.csv")
write.csv(csv_summary, csv_file, row.names = FALSE)

cat("\n📁 Results saved:\n")
cat(sprintf("   📊 Full results: %s\n", basename(results_file)))
cat(sprintf("   📋 JSON summary: %s\n", basename(summary_file)))
cat(sprintf("   📈 CSV summary: %s\n", basename(csv_file)))

cat("\n🎉 Simulation completed successfully!\n")
EOF

# Execute R script
print_status "Executing R simulation script..."
R --no-restore --slave < "$R_SCRIPT" 2>&1 | tee -a "$LOG_FILE"
R_EXIT_CODE=${PIPESTATUS[0]}

# Clean up temporary script
rm -f "$R_SCRIPT"

# Check if simulation succeeded
if [ $R_EXIT_CODE -eq 0 ]; then
    print_status "Simulation completed successfully!"
    
    # Generate plots if requested
    if [ "$GENERATE_PLOTS" = true ]; then
        print_status "Generating visualization plots..."
        # This would call a separate plotting script
        # Rscript scripts/generate_plots.R "$OUTPUT_DIR/${RUN_ID}_results.rds"
    fi
    
    print_status "Results available in: $OUTPUT_DIR"
    print_status "Log file: $LOG_FILE"
    
else
    print_error "Simulation failed with exit code $R_EXIT_CODE"
    print_error "Check log file: $LOG_FILE"
    exit 1
fi

print_status "Run completed: $RUN_ID"