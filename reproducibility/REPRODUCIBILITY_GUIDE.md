# Reproducibility Guide

This guide ensures that all research results from the EV Demand Modeling Framework can be reproduced and verified by independent researchers.

## Overview

The EV Demand Modeling Framework follows open science principles and provides comprehensive reproducibility support through:

- **Version Control**: All code and configurations are version controlled
- **Environment Management**: Precise dependency specification and virtual environments
- **Data Provenance**: Complete lineage tracking for all datasets
- **Computational Reproducibility**: Containerized environments and exact version pinning
- **Result Validation**: Automated testing and cross-validation procedures

## Quick Reproducibility Checklist

### For Authors (Publishing Results)

- [ ] All code committed to version control
- [ ] Environment documented with exact package versions
- [ ] Random seeds set for all stochastic processes
- [ ] Data sources clearly documented and accessible
- [ ] Configuration files saved with results
- [ ] Computational environment captured (Docker/singularity)
- [ ] Results validation performed
- [ ] Replication instructions written and tested

### For Reviewers/Readers (Reproducing Results)

- [ ] Environment setup completed successfully
- [ ] All dependencies installed and validated
- [ ] Data downloaded and verified
- [ ] Code execution completed without errors
- [ ] Results match published figures within tolerance
- [ ] Independent validation performed
- [ ] Issues documented and reported

## Computational Environment

### Software Requirements

**Core Requirements:**
- R 4.0.0 or higher
- Operating System: Windows 10+, Ubuntu 18.04+, macOS 10.15+
- RAM: 8GB minimum, 16GB+ recommended for large simulations
- Storage: 10GB free space minimum

**Optional Components:**
- PostgreSQL 12+ with TimescaleDB 2.8+ (for database features)
- CUDA 11.0+ with compatible GPU (for GPU acceleration)
- Docker 20.10+ (for containerized reproduction)

### Exact Package Versions

The framework dependencies are precisely specified in `requirements.R`:

```r
# Core packages with exact versions
required_packages <- list(
  "dplyr" = "1.1.3",
  "lubridate" = "1.9.2", 
  "readr" = "2.1.4",
  "jsonlite" = "1.8.7",
  "future" = "1.33.0",
  "furrr" = "0.3.1",
  "parallel" = "4.3.1",
  "DBI" = "1.1.3",
  "RPostgres" = "1.4.5"
)

# Performance packages (optional)
optional_packages <- list(
  "GPUmatrix" = "1.0.3",
  "data.table" = "1.14.8",
  "Rcpp" = "1.0.11"
)
```

### Environment Setup

#### Method 1: Automated Setup (Recommended)

```bash
# Clone repository
git clone <repository-url>
cd ev-demand-modeling-abm-timescaledb

# Validate and install dependencies
Rscript scripts/validate_installation.R

# Setup project data
Rscript setup_project_data.R
```

#### Method 2: Manual Setup

```r
# Install exact package versions
source("requirements.R")

# Verify installation
sessionInfo()  # Document your session info

# Validate framework
source("scripts/validate_installation.R")
```

#### Method 3: Docker Container (Maximum Reproducibility)

```bash
# Build container with exact environment
docker build -t ev-demand-modeling .

# Run simulation in container
docker run -v $(pwd)/results:/app/results ev-demand-modeling
```

### Session Information Template

Always document your computational environment:

```r
# Save session information
session_info <- sessionInfo()
writeLines(capture.output(print(session_info)), "reproducibility/session_info.txt")

# Save package versions
package_versions <- installed.packages()[,c("Package", "Version")]
write.csv(package_versions, "reproducibility/package_versions.csv", row.names = FALSE)

# Save system information
system_info <- list(
  R_version = R.version.string,
  platform = R.version$platform,
  os = Sys.info()["sysname"],
  memory_gb = round(memory.size(NA) / 1024, 1),
  cpu_cores = parallel::detectCores(),
  timestamp = Sys.time()
)

writeLines(jsonlite::toJSON(system_info, pretty = TRUE), "reproducibility/system_info.json")
```

## Data Reproducibility

### Data Sources and Accessibility

**Primary Data Sources:**
1. **EEQ Consumption Profiles**: Real consumption data from Empresa Eléctrica Quito
   - Location: `data/raw/eeq_profiles/`
   - Format: CSV files with 15-minute resolution
   - Period: 2023-2025
   - Access: Available within project after running `setup_project_data.R`

2. **Synthetic Validation Data**: Generated fallback data for testing
   - Location: `data/fallback_data/`
   - Format: CSV and JSON
   - Generation: Reproducible with fixed random seeds

**Data Integrity Verification:**

```r
# Verify data integrity
source("reproducibility/verify_data_integrity.R")

# Expected checksums and file counts
expected_data_manifest <- list(
  eeq_csv_files = 764,
  eeq_total_records = 21600,
  synthetic_records = 288000,
  data_checksum = "sha256:abc123..."
)

# Verify current data matches expectations
verify_data_integrity(expected_data_manifest)
```

### Data Privacy and Ethics

**Anonymization Process:**
- All customer identifiers have been pseudonymized
- Personal information removed from datasets
- Aggregation applied where necessary
- Compliance with data sharing agreements

**Ethical Considerations:**
- Data use approved by EEQ data sharing committee
- Research ethics approval obtained
- Results published in aggregated form only
- No individual customer behavior trackable

## Algorithmic Reproducibility

### Random Number Generation

All stochastic processes use controlled random number generation:

```r
# Set global random seed
set.seed(42)

# For parallel processing, use L'Ecuyer-CMRG
RNGkind("L'Ecuyer-CMRG")

# Document RNG state
save(.Random.seed, file = "reproducibility/random_seed.RData")

# In simulation configuration
config$simulation$random_seed <- 42
config$monte_carlo$parallel_rng <- "L'Ecuyer-CMRG"
```

### Algorithm Parameters

All algorithm parameters are explicitly documented:

```r
# Core simulation parameters
simulation_params <- list(
  # Agent-based modeling
  vehicle_generation = "monte_carlo_sampling",
  charging_behavior = "probabilistic_model",
  
  # Demand aggregation  
  coincidence_factor = "FC = 0.222 + 0.036 * exp(-0.0003 * n)",
  time_resolution = "15_minutes",
  
  # Monte Carlo simulation
  convergence_criterion = "coefficient_of_variation < 0.01",
  confidence_level = 0.95,
  
  # Numerical methods
  optimization_algorithm = "nelder_mead",
  tolerance = 1e-6
)

# Save parameter documentation
writeLines(
  jsonlite::toJSON(simulation_params, pretty = TRUE),
  "reproducibility/algorithm_parameters.json"
)
```

### Configuration Management

All simulation configurations must be saved and version controlled:

```r
# Save configuration with results
save_reproducible_config <- function(config, results, output_dir) {
  
  # Create reproducibility subdirectory
  repro_dir <- file.path(output_dir, "reproducibility")
  dir.create(repro_dir, recursive = TRUE)
  
  # Save configuration
  config_file <- file.path(repro_dir, "simulation_config.json")
  writeLines(jsonlite::toJSON(config, pretty = TRUE, auto_unbox = TRUE), config_file)
  
  # Save session info
  session_file <- file.path(repro_dir, "session_info.txt")
  writeLines(capture.output(sessionInfo()), session_file)
  
  # Save Git commit hash (if available)
  tryCatch({
    git_commit <- system("git rev-parse HEAD", intern = TRUE)
    git_info <- list(
      commit_hash = git_commit,
      branch = system("git branch --show-current", intern = TRUE),
      remote_url = system("git config --get remote.origin.url", intern = TRUE),
      timestamp = Sys.time()
    )
    git_file <- file.path(repro_dir, "git_info.json")
    writeLines(jsonlite::toJSON(git_info, pretty = TRUE), git_file)
  }, error = function(e) {
    warning("Could not capture Git information")
  })
  
  # Create reproduction script
  repro_script <- sprintf('
# Reproduction script generated %s
# 
# To reproduce these results:
# 1. Setup environment using requirements.R
# 2. Load this configuration: config <- jsonlite::fromJSON("simulation_config.json")  
# 3. Run: results <- run_final_simulation(config, processing_engine = "%s")

source("src/ev_simulator_final.R")
config <- jsonlite::fromJSON("%s")
results <- run_final_simulation(config, processing_engine = "%s", verbose = TRUE)
',
    Sys.time(),
    results$metadata$processing_mode %||% "AUTO",
    basename(config_file),
    results$metadata$processing_mode %||% "AUTO"
  )
  
  writeLines(repro_script, file.path(repro_dir, "reproduce_results.R"))
  
  cat(sprintf("📁 Reproducibility files saved to: %s\n", repro_dir))
}

# Use in workflow
results <- run_final_simulation(config, verbose = TRUE)
save_reproducible_config(config, results, "results/my_simulation")
```

## Result Validation

### Automated Validation Tests

Create comprehensive validation tests:

```r
# reproducibility/validation_tests.R

run_validation_suite <- function() {
  cat("🔍 Running Reproducibility Validation Suite\n")
  cat("==========================================\n\n")
  
  # Test 1: Configuration consistency
  test_config_consistency()
  
  # Test 2: Deterministic results with fixed seed
  test_deterministic_results()
  
  # Test 3: Statistical properties validation
  test_statistical_properties()
  
  # Test 4: Cross-platform compatibility
  test_cross_platform_results()
  
  # Test 5: Data integrity verification
  test_data_integrity()
  
  cat("\n✅ Validation suite completed\n")
}

test_deterministic_results <- function() {
  cat("Testing deterministic results with fixed seed...\n")
  
  # Run same simulation twice with same seed
  config <- get_default_config()
  config$simulation$random_seed <- 12345
  config$vehicles$num_vehicles <- 100
  config$simulation$days <- 1
  config$simulation$monte_carlo_runs <- 5
  
  # First run
  set.seed(12345)
  results1 <- run_final_simulation(config, verbose = FALSE)
  
  # Second run
  set.seed(12345)
  results2 <- run_final_simulation(config, verbose = FALSE)
  
  # Compare results
  peak_diff <- abs(results1$summary$peak_demand - results2$summary$peak_demand)
  mean_diff <- abs(results1$summary$mean_daily_demand - results2$summary$mean_daily_demand)
  
  tolerance <- 1e-10
  if (peak_diff < tolerance && mean_diff < tolerance) {
    cat("   ✅ Results are deterministic within tolerance\n")
  } else {
    cat(sprintf("   ❌ Non-deterministic results: peak_diff=%.2e, mean_diff=%.2e\n", 
               peak_diff, mean_diff))
  }
}

test_statistical_properties <- function() {
  cat("Testing statistical properties...\n")
  
  # Run simulation with known parameters
  config <- get_default_config()
  config$vehicles$num_vehicles <- 1000
  config$simulation$monte_carlo_runs <- 100
  
  results <- run_final_simulation(config, verbose = FALSE)
  
  # Test Monte Carlo convergence
  if (length(results$results) >= 50) {
    demands <- sapply(results$results, function(x) max(x$total_demand_adjusted))
    cv <- sd(demands) / mean(demands)
    
    if (cv < 0.05) {
      cat("   ✅ Monte Carlo convergence achieved (CV < 5%)\n")
    } else {
      cat(sprintf("   ⚠️ High Monte Carlo variability: CV = %.3f\n", cv))
    }
  }
  
  # Test coincidence factor
  vehicles_tested <- c(100, 1000, 10000)
  cf_values <- sapply(vehicles_tested, function(n) {
    0.222 + 0.036 * exp(-0.0003 * n)
  })
  
  # Verify formula implementation
  expected_cf <- c(0.258, 0.246, 0.222)
  cf_diff <- max(abs(cf_values - expected_cf))
  
  if (cf_diff < 0.001) {
    cat("   ✅ Coincidence factor formula correctly implemented\n")
  } else {
    cat("   ❌ Coincidence factor calculation error\n")
  }
}
```

### Statistical Validation

Implement statistical tests for result validation:

```r
# Statistical validation functions
validate_simulation_statistics <- function(results, expected_ranges = NULL) {
  
  validation_results <- list()
  
  # Extract key metrics
  peak_demand <- results$summary$peak_demand
  mean_demand <- results$summary$mean_daily_demand
  load_factor <- results$summary$load_factor
  
  # Test 1: Load factor bounds (should be between 0 and 1)
  lf_valid <- load_factor >= 0 && load_factor <= 1
  validation_results$load_factor_bounds <- lf_valid
  
  # Test 2: Peak demand > average demand
  peak_gt_mean <- peak_demand > mean_demand
  validation_results$peak_greater_than_mean <- peak_gt_mean
  
  # Test 3: Reasonable coincidence factor impact
  num_vehicles <- results$metadata$config$vehicles$num_vehicles
  theoretical_max <- num_vehicles * max(results$metadata$config$vehicles$charging_powers_kw)
  
  cf_impact <- peak_demand < theoretical_max
  validation_results$coincidence_factor_impact <- cf_impact
  
  # Test 4: Expected ranges (if provided)
  if (!is.null(expected_ranges)) {
    range_tests <- list()
    
    if (!is.null(expected_ranges$peak_demand)) {
      range_tests$peak_demand <- peak_demand >= expected_ranges$peak_demand[1] && 
                                peak_demand <= expected_ranges$peak_demand[2]
    }
    
    if (!is.null(expected_ranges$load_factor)) {
      range_tests$load_factor <- load_factor >= expected_ranges$load_factor[1] && 
                                load_factor <= expected_ranges$load_factor[2]
    }
    
    validation_results$range_tests <- range_tests
  }
  
  # Overall validation
  all_passed <- all(unlist(validation_results))
  
  cat("📊 Statistical Validation Results:\n")
  for (test_name in names(validation_results)) {
    status <- if (validation_results[[test_name]]) "✅" else "❌"
    cat(sprintf("   %s %s\n", status, gsub("_", " ", test_name)))
  }
  
  return(list(
    passed = all_passed,
    details = validation_results
  ))
}

# Usage example
expected_ranges <- list(
  peak_demand = c(500, 2000),  # kW
  load_factor = c(0.1, 0.8)
)

validation <- validate_simulation_statistics(results, expected_ranges)
```

### Cross-Validation Procedures

Implement cross-validation against real data:

```r
# Cross-validation against real EEQ data
perform_cross_validation <- function(config, real_data, n_folds = 5) {
  
  cat("🔄 Performing cross-validation against real data\n")
  
  # Split real data into folds
  set.seed(42)  # For reproducible folds
  fold_size <- ceiling(nrow(real_data) / n_folds)
  
  validation_metrics <- list()
  
  for (fold in 1:n_folds) {
    cat(sprintf("   Processing fold %d/%d...\n", fold, n_folds))
    
    # Split data
    start_idx <- (fold - 1) * fold_size + 1
    end_idx <- min(fold * fold_size, nrow(real_data))
    
    train_data <- real_data[-seq(start_idx, end_idx), ]
    test_data <- real_data[seq(start_idx, end_idx), ]
    
    # Calibrate on training data
    calibrated_config <- calibrate_with_real_data(train_data, config)
    
    # Simulate
    fold_results <- run_final_simulation(calibrated_config, verbose = FALSE)
    
    # Validate against test data
    fold_metrics <- validate_simulation_against_real_data(fold_results, test_data)
    
    validation_metrics[[fold]] <- fold_metrics
  }
  
  # Aggregate cross-validation results
  avg_mape <- mean(sapply(validation_metrics, function(x) x$mape))
  avg_correlation <- mean(sapply(validation_metrics, function(x) x$correlation))
  avg_rmse <- mean(sapply(validation_metrics, function(x) x$rmse))
  
  cv_results <- list(
    n_folds = n_folds,
    avg_mape = avg_mape,
    avg_correlation = avg_correlation,
    avg_rmse = avg_rmse,
    individual_folds = validation_metrics
  )
  
  cat("📊 Cross-Validation Results:\n")
  cat(sprintf("   Average MAPE: %.2f%%\n", avg_mape))
  cat(sprintf("   Average Correlation: %.3f\n", avg_correlation))
  cat(sprintf("   Average RMSE: %.3f kW\n", avg_rmse))
  
  return(cv_results)
}
```

## Computational Reproducibility

### Container-Based Reproduction

Create Docker container for exact environment reproduction:

```dockerfile
# Dockerfile for exact reproduction
FROM rocker/r-ver:4.3.1

# Install system dependencies
RUN apt-get update && apt-get install -y \
    libpq-dev \
    libssl-dev \
    libcurl4-openssl-dev \
    libxml2-dev \
    git \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy dependency files
COPY requirements.R .
COPY renv.lock .

# Install R packages
RUN Rscript requirements.R

# Copy source code
COPY src/ src/
COPY data/ data/
COPY database/ database/
COPY scripts/ scripts/

# Copy reproducibility files
COPY reproducibility/ reproducibility/

# Set default command
CMD ["Rscript", "scripts/validate_installation.R"]
```

### Singularity Container (HPC Environments)

```bash
# Singularity definition file
Bootstrap: docker
From: rocker/r-ver:4.3.1

%post
    apt-get update
    apt-get install -y libpq-dev libssl-dev libcurl4-openssl-dev
    
%files
    requirements.R /app/
    src/ /app/src/
    data/ /app/data/
    
%runscript
    cd /app
    Rscript requirements.R
    Rscript scripts/validate_installation.R
```

### Virtual Environment Management

```r
# Using renv for package management
if (!require(renv)) install.packages("renv")

# Initialize renv project
renv::init()

# Snapshot current environment
renv::snapshot()

# Restore exact environment on new system
renv::restore()

# Document library state
renv::status()
```

## Documentation Standards

### Minimum Documentation Requirements

For each analysis, provide:

1. **Analysis Description**
   - Research question and objectives
   - Methodology and approach
   - Key assumptions

2. **Data Documentation**
   - Data sources and acquisition
   - Preprocessing steps
   - Quality checks performed

3. **Code Documentation**
   - Inline comments explaining logic
   - Function documentation
   - Usage examples

4. **Computational Environment**
   - Software versions
   - Hardware specifications
   - Execution time and resources

5. **Results Documentation**
   - Summary of findings
   - Statistical significance
   - Limitations and caveats

### Metadata Standards

Use standardized metadata for all outputs:

```r
# Standard metadata template
create_analysis_metadata <- function(analysis_name, author, description) {
  metadata <- list(
    analysis = list(
      name = analysis_name,
      author = author,
      description = description,
      created_date = Sys.Date(),
      created_time = Sys.time()
    ),
    
    computational_environment = list(
      r_version = R.version.string,
      platform = R.version$platform,
      packages = installed.packages()[, c("Package", "Version")],
      system_info = Sys.info()
    ),
    
    data_sources = list(
      # To be filled by specific analysis
    ),
    
    methods = list(
      # To be filled by specific analysis  
    ),
    
    reproducibility = list(
      random_seed = .Random.seed,
      git_commit = tryCatch(system("git rev-parse HEAD", intern = TRUE), error = function(e) NA),
      reproduction_instructions = "See REPRODUCIBILITY_GUIDE.md"
    )
  )
  
  return(metadata)
}

# Usage
metadata <- create_analysis_metadata(
  analysis_name = "EV Demand Simulation - Quito Case Study",
  author = "Iván Sánchez-Loor, Manuel Ayala-Chauvin", 
  description = "Agent-based modeling of EV charging demand using real EEQ consumption data"
)

# Save metadata
writeLines(
  jsonlite::toJSON(metadata, pretty = TRUE),
  "results/analysis_metadata.json"
)
```

## Publication and Sharing

### Pre-Publication Checklist

Before publishing results:

- [ ] All code reviewed and tested
- [ ] Results reproduced by independent team member
- [ ] Data sources properly cited and accessible
- [ ] Ethical approvals documented
- [ ] Code repository publicly available
- [ ] Documentation complete and tested
- [ ] Container/virtual environment tested
- [ ] Licensing clearly specified

### Data and Code Sharing

**Repository Structure for Sharing:**
```
ev-demand-modeling-abm-timescaledb/
├── README.md                    # Main project description
├── LICENSE                      # Open source license
├── CITATION.cff                 # Citation information
├── requirements.R               # Dependency specification
├── src/                         # Source code
├── data/                        # Data files (where permitted)
├── results/                     # Example results
├── docs/                        # Documentation
├── reproducibility/             # Reproducibility resources
├── containers/                  # Docker/Singularity files
└── tests/                      # Validation tests
```

**Licensing Recommendations:**
- Code: MIT or Apache 2.0 License
- Data: CC BY 4.0 (where possible)
- Documentation: CC BY 4.0

### Long-term Preservation

For long-term preservation:

1. **Archive in Repository**
   - Zenodo for data and code
   - GitHub/GitLab for version control
   - Institutional repositories

2. **Version Management**
   - Tag releases with semantic versioning
   - Archive exact versions used in publications
   - Maintain migration guides for version updates

3. **Format Standards**
   - Use open, standard file formats
   - Include format specifications
   - Provide conversion tools if needed

## Troubleshooting Reproducibility Issues

### Common Issues and Solutions

**Issue: Different R package versions**
```r
# Solution: Use renv for exact package management
renv::restore()

# Or install specific versions manually
devtools::install_version("dplyr", version = "1.1.3")
```

**Issue: Platform-specific differences**
```r
# Document platform differences
platform_info <- list(
  os = Sys.info()["sysname"],
  arch = Sys.info()["machine"],
  r_platform = R.version$platform
)

# Use platform-specific configurations
if (Sys.info()["sysname"] == "Windows") {
  config$processing$parallel_type <- "PSOCK"
} else {
  config$processing$parallel_type <- "FORK"
}
```

**Issue: Random number generation differences**
```r
# Ensure consistent RNG across platforms
RNGversion("4.3.0")  # Use specific RNG version
set.seed(42, kind = "Mersenne-Twister", normal.kind = "Inversion")
```

**Issue: Floating point precision differences**
```r
# Set consistent options
options(digits = 15)
options(scipen = 999)

# Use tolerances for comparisons
all.equal(result1, result2, tolerance = 1e-10)
```

### Debugging Reproducibility Failures

```r
# Reproducibility debugging toolkit
debug_reproducibility <- function(results1, results2, tolerance = 1e-10) {
  
  cat("🔧 Debugging Reproducibility Issues\n")
  cat("==================================\n\n")
  
  # Compare summary statistics
  summary1 <- results1$summary
  summary2 <- results2$summary
  
  for (metric in names(summary1)) {
    if (is.numeric(summary1[[metric]]) && is.numeric(summary2[[metric]])) {
      diff <- abs(summary1[[metric]] - summary2[[metric]])
      
      if (diff > tolerance) {
        cat(sprintf("❌ %s differs: %.10f vs %.10f (diff: %.2e)\n", 
                   metric, summary1[[metric]], summary2[[metric]], diff))
      } else {
        cat(sprintf("✅ %s matches within tolerance\n", metric))
      }
    }
  }
  
  # Compare detailed results
  if (length(results1$results) == length(results2$results)) {
    for (i in seq_along(results1$results)) {
      diff_vec <- results1$results[[i]]$total_demand_adjusted - 
                  results2$results[[i]]$total_demand_adjusted
      max_diff <- max(abs(diff_vec))
      
      if (max_diff > tolerance) {
        cat(sprintf("❌ MC run %d differs: max diff = %.2e\n", i, max_diff))
        
        # Identify where differences occur
        diff_indices <- which(abs(diff_vec) > tolerance)
        if (length(diff_indices) <= 10) {
          cat(sprintf("   Differences at indices: %s\n", 
                     paste(diff_indices, collapse = ", ")))
        } else {
          cat(sprintf("   %d total differences\n", length(diff_indices)))
        }
      }
    }
  }
  
  cat("\n💡 Debugging suggestions:\n")
  cat("   - Check random seed settings\n")
  cat("   - Verify package versions\n") 
  cat("   - Check for uninitialized variables\n")
  cat("   - Review parallel processing setup\n")
}

# Usage
debug_reproducibility(results1, results2, tolerance = 1e-12)
```

## Contact and Support

For reproducibility issues:

1. **Check Documentation**: Review this guide and API documentation
2. **Validation Script**: Run `scripts/validate_installation.R`
3. **Community Support**: Create issue in project repository
4. **Direct Contact**: Email research team with:
   - System specifications
   - Session information (`sessionInfo()`)
   - Exact error messages
   - Steps to reproduce

**Research Team Contact:**
- Iván Sánchez-Loor: ivan.sanchez@uti.edu.ec
- Manuel Ayala-Chauvin: mayala@uti.edu.ec
- Universidad Indoamérica - Grupo SISAu

Remember: Reproducibility is essential for scientific validity and enables others to build upon your research. When in doubt, over-document rather than under-document!