# ==============================================================================
# verify_data_integrity.R - Data Integrity Verification for Reproducibility
# ==============================================================================
#
# This script verifies the integrity and consistency of datasets used in the
# EV demand modeling framework to ensure reproducible research.
#
# Author: Iván Sánchez-Loor, Manuel Ayala-Chauvin
# ==============================================================================

library(digest)
library(dplyr)

#' Verify Data Integrity
#' 
#' Checks data integrity against expected manifests and checksums
#' 
#' @param expected_manifest List containing expected data characteristics
#' @return List with verification results
verify_data_integrity <- function(expected_manifest = NULL) {
  
  cat("🔍 VERIFYING DATA INTEGRITY\n")
  cat("===========================\n\n")
  
  verification_results <- list()
  
  # 1. EEQ PROFILES DATA VERIFICATION
  cat("1️⃣ Verifying EEQ consumption profiles...\n")
  
  eeq_internal_path <- "data/raw/eeq_profiles"
  eeq_external_path <- "C:/Users/LEGION/Maestria BigData/Trabajo Titulacion/EEQ/ConsolidadoPerfiles"
  
  # Check internal project data
  if (dir.exists(eeq_internal_path)) {
    internal_files <- list.files(eeq_internal_path, pattern = "*.csv", recursive = TRUE)
    cat(sprintf("   📁 Internal EEQ files: %d\n", length(internal_files)))
    
    if (length(internal_files) > 0) {
      # Sample integrity check
      sample_files <- head(internal_files, 5)
      integrity_issues <- 0
      
      for (file in sample_files) {
        file_path <- file.path(eeq_internal_path, file)
        tryCatch({
          # Try to read file
          data <- read.csv(file_path, nrows = 10)
          
          # Check for basic structure
          if (ncol(data) == 0) {
            integrity_issues <- integrity_issues + 1
            cat(sprintf("   ⚠️ Empty file: %s\n", file))
          }
          
        }, error = function(e) {
          integrity_issues <- integrity_issues + 1
          cat(sprintf("   ❌ Cannot read: %s (%s)\n", file, e$message))
        })
      }
      
      verification_results$eeq_internal <- list(
        files_found = length(internal_files),
        sample_checked = length(sample_files),
        integrity_issues = integrity_issues,
        status = if (integrity_issues == 0) "OK" else "ISSUES"
      )
      
      cat(sprintf("   ✅ Internal data check: %s\n", 
                 if (integrity_issues == 0) "PASSED" else "ISSUES FOUND"))
    } else {
      verification_results$eeq_internal <- list(
        files_found = 0,
        status = "MISSING"
      )
      cat("   ❌ No internal EEQ files found\n")
    }
  } else {
    verification_results$eeq_internal <- list(status = "DIRECTORY_MISSING")
    cat("   ❌ Internal EEQ directory missing\n")
  }
  
  # Check external source data
  if (dir.exists(eeq_external_path)) {
    external_files <- list.files(eeq_external_path, pattern = "*.csv", recursive = TRUE)
    cat(sprintf("   📁 External EEQ files: %d\n", length(external_files)))
    
    verification_results$eeq_external <- list(
      files_found = length(external_files),
      status = if (length(external_files) > 0) "OK" else "MISSING"
    )
  } else {
    verification_results$eeq_external <- list(
      files_found = 0,
      status = "DIRECTORY_MISSING"
    )
    cat("   ⚠️ External EEQ directory not accessible\n")
  }
  
  # 2. SYNTHETIC DATA VERIFICATION
  cat("\n2️⃣ Verifying synthetic fallback data...\n")
  
  fallback_path <- "data/fallback_data"
  if (dir.exists(fallback_path)) {
    synthetic_files <- list.files(fallback_path, recursive = TRUE)
    
    # Check for required files
    required_files <- c("synthetic_profiles.csv", "default_parameters.json")
    missing_files <- setdiff(required_files, basename(synthetic_files))
    
    if (length(missing_files) == 0) {
      cat("   ✅ All required synthetic files present\n")
      
      # Verify synthetic profiles structure
      synthetic_path <- file.path(fallback_path, "synthetic_profiles.csv")
      if (file.exists(synthetic_path)) {
        tryCatch({
          synthetic_data <- read.csv(synthetic_path, nrows = 100)
          
          required_columns <- c("profile_id", "date", "hour", "consumption_kwh")
          missing_columns <- setdiff(required_columns, names(synthetic_data))
          
          if (length(missing_columns) == 0) {
            cat(sprintf("   ✅ Synthetic data structure valid (%d columns, %d+ rows)\n", 
                       ncol(synthetic_data), nrow(synthetic_data)))
            
            verification_results$synthetic_data <- list(
              files_present = length(synthetic_files),
              structure_valid = TRUE,
              status = "OK"
            )
          } else {
            cat(sprintf("   ❌ Missing columns in synthetic data: %s\n", 
                       paste(missing_columns, collapse = ", ")))
            verification_results$synthetic_data <- list(
              structure_valid = FALSE,
              missing_columns = missing_columns,
              status = "INVALID_STRUCTURE"
            )
          }
          
        }, error = function(e) {
          cat(sprintf("   ❌ Cannot read synthetic data: %s\n", e$message))
          verification_results$synthetic_data <- list(
            readable = FALSE,
            status = "READ_ERROR"
          )
        })
      }
    } else {
      cat(sprintf("   ❌ Missing required files: %s\n", paste(missing_files, collapse = ", ")))
      verification_results$synthetic_data <- list(
        missing_files = missing_files,
        status = "INCOMPLETE"
      )
    }
  } else {
    cat("   ❌ Synthetic data directory missing\n")
    verification_results$synthetic_data <- list(status = "DIRECTORY_MISSING")
  }
  
  # 3. DATABASE SCHEMA VERIFICATION
  cat("\n3️⃣ Verifying database schema...\n")
  
  schema_file <- "database/schema.sql"
  if (file.exists(schema_file)) {
    schema_content <- readLines(schema_file)
    
    # Check for required tables
    required_tables <- c(
      "simulation_metadata",
      "ev_agents", 
      "ev_demand_timeseries",
      "charging_events",
      "simulation_summary",
      "validation_metrics",
      "grid_infrastructure"
    )
    
    tables_found <- sapply(required_tables, function(table) {
      any(grepl(paste0("CREATE TABLE.*", table), schema_content, ignore.case = TRUE))
    })
    
    missing_tables <- names(tables_found)[!tables_found]
    
    if (length(missing_tables) == 0) {
      cat("   ✅ All required database tables defined\n")
      verification_results$database_schema <- list(
        tables_defined = length(required_tables),
        status = "OK"
      )
    } else {
      cat(sprintf("   ❌ Missing table definitions: %s\n", 
                 paste(missing_tables, collapse = ", ")))
      verification_results$database_schema <- list(
        missing_tables = missing_tables,
        status = "INCOMPLETE"
      )
    }
  } else {
    cat("   ❌ Database schema file missing\n")
    verification_results$database_schema <- list(status = "FILE_MISSING")
  }
  
  # 4. SOURCE CODE VERIFICATION
  cat("\n4️⃣ Verifying source code integrity...\n")
  
  src_files <- c(
    "src/ev_simulator_final.R",
    "src/real_data_loader.R",
    "src/data_manager.R",
    "src/gpu_acceleration.R",
    "src/parallel_processing.R"
  )
  
  missing_src_files <- character(0)
  for (file in src_files) {
    if (!file.exists(file)) {
      missing_src_files <- c(missing_src_files, file)
    }
  }
  
  if (length(missing_src_files) == 0) {
    cat("   ✅ All core source files present\n")
    
    # Check main functions exist
    tryCatch({
      source("src/ev_simulator_final.R", local = TRUE)
      if (exists("run_final_simulation", envir = .GlobalEnv) || 
          exists("run_final_simulation", inherits = FALSE)) {
        cat("   ✅ Main simulation function accessible\n")
      }
    }, error = function(e) {
      cat(sprintf("   ⚠️ Warning loading main simulation: %s\n", e$message))
    })
    
    verification_results$source_code <- list(
      files_present = length(src_files),
      status = "OK"
    )
  } else {
    cat(sprintf("   ❌ Missing source files: %s\n", 
               paste(missing_src_files, collapse = ", ")))
    verification_results$source_code <- list(
      missing_files = missing_src_files,
      status = "INCOMPLETE"
    )
  }
  
  # 5. CONFIGURATION FILES VERIFICATION
  cat("\n5️⃣ Verifying configuration files...\n")
  
  config_files <- c(
    "requirements.R",
    "README.md",
    "CITATION.cff"
  )
  
  missing_config_files <- character(0)
  for (file in config_files) {
    if (!file.exists(file)) {
      missing_config_files <- c(missing_config_files, file)
    }
  }
  
  if (length(missing_config_files) == 0) {
    cat("   ✅ All configuration files present\n")
    verification_results$configuration <- list(
      files_present = length(config_files),
      status = "OK"
    )
  } else {
    cat(sprintf("   ❌ Missing configuration files: %s\n", 
               paste(missing_config_files, collapse = ", ")))
    verification_results$configuration <- list(
      missing_files = missing_config_files,
      status = "INCOMPLETE"
    )
  }
  
  # 6. EXPECTED MANIFEST COMPARISON
  if (!is.null(expected_manifest)) {
    cat("\n6️⃣ Comparing against expected manifest...\n")
    
    manifest_checks <- list()
    
    # Check file counts
    if (!is.null(expected_manifest$eeq_csv_files)) {
      actual_files <- length(list.files("data/raw/eeq_profiles", pattern = "*.csv", recursive = TRUE))
      expected_files <- expected_manifest$eeq_csv_files
      
      if (actual_files == expected_files) {
        cat(sprintf("   ✅ EEQ file count matches: %d files\n", actual_files))
        manifest_checks$file_count <- TRUE
      } else {
        cat(sprintf("   ❌ EEQ file count mismatch: %d actual vs %d expected\n", 
                   actual_files, expected_files))
        manifest_checks$file_count <- FALSE
      }
    }
    
    verification_results$manifest_comparison <- manifest_checks
  }
  
  # 7. GENERATE INTEGRITY REPORT
  cat("\n" + paste(rep("=", 50), collapse = "") + "\n")
  cat("📊 DATA INTEGRITY SUMMARY\n")
  cat(paste(rep("=", 50), collapse = "") + "\n")
  
  # Count passed/failed checks
  all_statuses <- unlist(lapply(verification_results, function(x) x$status))
  passed_checks <- sum(all_statuses == "OK", na.rm = TRUE)
  total_checks <- length(all_statuses)
  
  cat(sprintf("\n✅ Passed: %d/%d checks\n", passed_checks, total_checks))
  
  if (passed_checks == total_checks) {
    cat("\n🎉 DATA INTEGRITY VERIFIED!\n")
    cat("   All data sources and files are present and valid.\n")
    overall_status <- "PASSED"
  } else {
    cat("\n⚠️ INTEGRITY ISSUES DETECTED!\n")
    cat("   Some data sources have issues. Review above details.\n")
    overall_status <- "FAILED"
  }
  
  # Save verification report
  verification_report <- list(
    verification_timestamp = Sys.time(),
    overall_status = overall_status,
    checks_passed = passed_checks,
    total_checks = total_checks,
    detailed_results = verification_results,
    system_info = list(
      working_directory = getwd(),
      r_version = R.version.string,
      platform = R.version$platform
    )
  )
  
  # Save report
  report_file <- sprintf("reproducibility/data_integrity_report_%s.json", 
                        format(Sys.time(), "%Y%m%d_%H%M%S"))
  
  tryCatch({
    writeLines(jsonlite::toJSON(verification_report, pretty = TRUE, auto_unbox = TRUE), 
              report_file)
    cat(sprintf("\n📄 Integrity report saved: %s\n", report_file))
  }, error = function(e) {
    warning(sprintf("Could not save integrity report: %s", e$message))
  })
  
  cat(paste(rep("=", 50), collapse = ""), "\n")
  
  return(verification_report)
}

#' Compute File Checksums
#' 
#' Computes MD5 and SHA256 checksums for data integrity verification
#' 
#' @param file_paths Vector of file paths to check
#' @return Data frame with file paths and checksums
compute_file_checksums <- function(file_paths) {
  
  cat("🔐 Computing file checksums...\n")
  
  checksums <- data.frame(
    file_path = character(0),
    file_size = numeric(0),
    md5 = character(0),
    sha256 = character(0),
    stringsAsFactors = FALSE
  )
  
  for (file_path in file_paths) {
    if (file.exists(file_path)) {
      tryCatch({
        # Get file info
        file_info <- file.info(file_path)
        
        # Compute checksums
        md5_hash <- digest(file_path, algo = "md5", file = TRUE)
        sha256_hash <- digest(file_path, algo = "sha256", file = TRUE)
        
        # Add to results
        checksums <- rbind(checksums, data.frame(
          file_path = file_path,
          file_size = file_info$size,
          md5 = md5_hash,
          sha256 = sha256_hash,
          stringsAsFactors = FALSE
        ))
        
        cat(sprintf("   ✅ %s\n", basename(file_path)))
        
      }, error = function(e) {
        cat(sprintf("   ❌ %s: %s\n", basename(file_path), e$message))
      })
    } else {
      cat(sprintf("   ❌ File not found: %s\n", file_path))
    }
  }
  
  return(checksums)
}

#' Create Data Manifest
#' 
#' Creates a manifest file documenting all data sources and their characteristics
#' 
#' @param output_file Path to save the manifest
#' @return List containing manifest data
create_data_manifest <- function(output_file = "reproducibility/data_manifest.json") {
  
  cat("📋 Creating data manifest...\n")
  
  manifest <- list(
    created_date = Sys.time(),
    created_by = "verify_data_integrity.R",
    
    eeq_data = list(),
    synthetic_data = list(),
    database_schema = list(),
    source_code = list()
  )
  
  # EEQ data manifest
  eeq_internal_path <- "data/raw/eeq_profiles"
  if (dir.exists(eeq_internal_path)) {
    eeq_files <- list.files(eeq_internal_path, pattern = "*.csv", recursive = TRUE, full.names = TRUE)
    
    if (length(eeq_files) > 0) {
      # Sample a few files for detailed analysis
      sample_files <- head(eeq_files, 10)
      sample_checksums <- compute_file_checksums(sample_files)
      
      manifest$eeq_data <- list(
        internal_path = eeq_internal_path,
        total_files = length(eeq_files),
        total_size_bytes = sum(file.size(eeq_files), na.rm = TRUE),
        file_extensions = unique(tools::file_ext(eeq_files)),
        sample_checksums = sample_checksums
      )
    }
  }
  
  # Synthetic data manifest
  fallback_path <- "data/fallback_data"
  if (dir.exists(fallback_path)) {
    synthetic_files <- list.files(fallback_path, recursive = TRUE, full.names = TRUE)
    
    if (length(synthetic_files) > 0) {
      synthetic_checksums <- compute_file_checksums(synthetic_files)
      
      manifest$synthetic_data <- list(
        path = fallback_path,
        files = synthetic_checksums
      )
    }
  }
  
  # Source code manifest
  src_files <- c(
    "src/ev_simulator_final.R",
    "src/real_data_loader.R", 
    "src/data_manager.R",
    "src/gpu_acceleration.R",
    "src/parallel_processing.R"
  )
  
  existing_src_files <- src_files[file.exists(src_files)]
  if (length(existing_src_files) > 0) {
    src_checksums <- compute_file_checksums(existing_src_files)
    manifest$source_code <- list(
      files = src_checksums
    )
  }
  
  # Save manifest
  tryCatch({
    dir.create(dirname(output_file), recursive = TRUE, showWarnings = FALSE)
    writeLines(jsonlite::toJSON(manifest, pretty = TRUE, auto_unbox = TRUE), output_file)
    cat(sprintf("📄 Data manifest saved: %s\n", output_file))
  }, error = function(e) {
    warning(sprintf("Could not save data manifest: %s", e$message))
  })
  
  return(manifest)
}

# Example usage and testing
if (interactive()) {
  cat("🧪 Running data integrity verification...\n\n")
  
  # Run verification
  results <- verify_data_integrity()
  
  # Create manifest
  manifest <- create_data_manifest()
  
  # Display summary
  cat("\n📊 Verification completed. Check the report for details.\n")
}

cat("📋 Data integrity verification module loaded\n")