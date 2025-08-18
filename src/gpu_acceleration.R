# ==============================================================================
# gpu_acceleration.R - GPU Acceleration Module for EV Demand Modeling
# ==============================================================================
#
# This module provides GPU acceleration capabilities for the EV demand modeling
# framework using GPUmatrix and CUDA. It handles large-scale matrix operations
# and parallel computations to significantly speed up simulations.
#
# Requirements:
# - CUDA-compatible GPU (Compute Capability 3.5+)
# - NVIDIA drivers and CUDA toolkit
# - R package: GPUmatrix
#
# Author: Iván Sánchez-Loor, Manuel Ayala-Chauvin
# Institution: Universidad Indoamérica - SISAu Research Group
# ==============================================================================

# Try to load GPU acceleration library
gpu_available <- tryCatch({
  suppressPackageStartupMessages({
    library(GPUmatrix)
  })
  TRUE
}, error = function(e) {
  message("GPU acceleration not available: ", e$message)
  FALSE
})

#' Check GPU Availability
#' 
#' Checks if GPU is available and provides system information
#' 
#' @return List with GPU status and information
check_gpu_availability <- function() {
  if (!gpu_available) {
    return(list(
      available = FALSE,
      message = "GPUmatrix package not installed or GPU not available"
    ))
  }
  
  tryCatch({
    # Get GPU information
    gpu_info <- gpu.summary()
    
    return(list(
      available = TRUE,
      gpu_count = gpu_info$GPU.count,
      total_memory = gpu_info$Total.memory,
      free_memory = gpu_info$Free.memory,
      driver_version = gpu_info$Driver.version,
      cuda_version = gpu_info$CUDA.version,
      message = "GPU acceleration available"
    ))
  }, error = function(e) {
    return(list(
      available = FALSE,
      message = paste("GPU check failed:", e$message)
    ))
  })
}

#' Initialize GPU Processing
#' 
#' Sets up GPU environment for simulation
#' 
#' @param verbose Logical: print status messages
#' @return Logical: TRUE if successful
initialize_gpu_processing <- function(verbose = TRUE) {
  if (!gpu_available) {
    if (verbose) cat("❌ GPU not available\n")
    return(FALSE)
  }
  
  tryCatch({
    # Check GPU status
    gpu_status <- check_gpu_availability()
    
    if (!gpu_status$available) {
      if (verbose) cat("❌ GPU initialization failed:", gpu_status$message, "\n")
      return(FALSE)
    }
    
    if (verbose) {
      cat("🚀 GPU acceleration initialized\n")
      cat(sprintf("   📱 GPU count: %d\n", gpu_status$gpu_count))
      cat(sprintf("   💾 Total memory: %.1f GB\n", gpu_status$total_memory / 1024^3))
      cat(sprintf("   💾 Free memory: %.1f GB\n", gpu_status$free_memory / 1024^3))
      cat(sprintf("   🔧 CUDA version: %s\n", gpu_status$cuda_version))
    }
    
    # Set GPU options
    options(GPUmatrix.default.device = 0)  # Use first GPU
    
    return(TRUE)
  }, error = function(e) {
    if (verbose) cat("❌ GPU initialization error:", e$message, "\n")
    return(FALSE)
  })
}

#' Create GPU Matrix
#' 
#' Creates a matrix on GPU memory
#' 
#' @param data Matrix data or dimensions
#' @param nrow Number of rows (if data is scalar)
#' @param ncol Number of columns (if data is scalar) 
#' @param sparse Logical: create sparse matrix
#' @return gpu.matrix object
create_gpu_matrix <- function(data, nrow = NULL, ncol = NULL, sparse = FALSE) {
  if (!gpu_available) {
    stop("GPU not available")
  }
  
  tryCatch({
    if (is.matrix(data)) {
      if (sparse) {
        return(gpu.matrix(data, sparse = TRUE))
      } else {
        return(gpu.matrix(data))
      }
    } else if (is.numeric(data) && !is.null(nrow) && !is.null(ncol)) {
      if (sparse) {
        return(gpu.matrix(data, nrow = nrow, ncol = ncol, sparse = TRUE))
      } else {
        return(gpu.matrix(data, nrow = nrow, ncol = ncol))
      }
    } else {
      stop("Invalid input for GPU matrix creation")
    }
  }, error = function(e) {
    stop("Failed to create GPU matrix: ", e$message)
  })
}

#' GPU Monte Carlo Simulation
#' 
#' Runs Monte Carlo simulation using GPU acceleration
#' 
#' @param scenarios List of simulation scenarios
#' @param config Configuration parameters
#' @param progress_callback Progress reporting function
#' @return List of simulation results
run_gpu_monte_carlo <- function(scenarios, config, progress_callback = NULL) {
  if (!gpu_available) {
    stop("GPU not available for Monte Carlo simulation")
  }
  
  n_scenarios <- length(scenarios)
  n_agents <- config$vehicles$num_vehicles
  time_steps <- config$simulation$days * (24 * 60 / config$simulation$time_resolution)
  
  tryCatch({
    # Pre-allocate GPU matrices for batch processing
    batch_size <- min(100, n_scenarios)  # Process in batches to manage memory
    results <- vector("list", n_scenarios)
    
    for (batch_start in seq(1, n_scenarios, by = batch_size)) {
      batch_end <- min(batch_start + batch_size - 1, n_scenarios)
      batch_scenarios <- scenarios[batch_start:batch_end]
      
      # Process batch on GPU
      batch_results <- process_gpu_batch(batch_scenarios, config)
      
      # Store results
      for (i in seq_along(batch_results)) {
        results[[batch_start + i - 1]] <- batch_results[[i]]
      }
      
      # Update progress
      if (!is.null(progress_callback)) {
        for (i in 1:length(batch_scenarios)) {
          progress_callback()
        }
      }
      
      # Memory cleanup
      gc()
    }
    
    return(results)
    
  }, error = function(e) {
    warning("GPU Monte Carlo failed, falling back to CPU: ", e$message)
    # Fallback to CPU processing
    return(run_cpu_monte_carlo_fallback(scenarios, config, progress_callback))
  })
}

#' Process GPU Batch
#' 
#' Processes a batch of scenarios on GPU
#' 
#' @param batch_scenarios List of scenarios in the batch
#' @param config Configuration parameters
#' @return List of batch results
process_gpu_batch <- function(batch_scenarios, config) {
  batch_size <- length(batch_scenarios)
  n_agents <- nrow(batch_scenarios[[1]]$agents)
  time_steps <- length(create_time_series(
    batch_scenarios[[1]]$start_date,
    batch_scenarios[[1]]$days,
    batch_scenarios[[1]]$time_resolution
  ))
  
  # Create agent parameter matrices on GPU
  agent_matrix <- create_agent_parameter_matrix(batch_scenarios[[1]]$agents)
  gpu_agents <- create_gpu_matrix(agent_matrix)
  
  # Pre-allocate result matrices
  gpu_demand_batch <- create_gpu_matrix(0, nrow = batch_size, ncol = time_steps)
  
  # Process each scenario in the batch
  for (scenario_idx in seq_along(batch_scenarios)) {
    scenario <- batch_scenarios[[scenario_idx]]
    
    # Generate random parameters for this scenario
    random_params <- generate_gpu_random_parameters(scenario, config)
    gpu_random <- create_gpu_matrix(random_params)
    
    # Compute demand profile using GPU matrix operations
    demand_profile <- compute_gpu_demand_profile(
      gpu_agents, 
      gpu_random, 
      config
    )
    
    # Store result
    gpu_demand_batch[scenario_idx, ] <- demand_profile
  }
  
  # Transfer results back to CPU
  cpu_demand_batch <- as.matrix(gpu_demand_batch)
  
  # Format results
  results <- vector("list", batch_size)
  for (i in 1:batch_size) {
    time_series <- create_time_series(
      batch_scenarios[[i]]$start_date,
      batch_scenarios[[i]]$days,
      batch_scenarios[[i]]$time_resolution
    )
    
    results[[i]] <- list(
      run_id = batch_scenarios[[i]]$run_id,
      time_series = time_series,
      total_demand = cpu_demand_batch[i, ],
      agents = batch_scenarios[[i]]$agents
    )
  }
  
  return(results)
}

#' Create Agent Parameter Matrix
#' 
#' Converts agent data frame to matrix for GPU processing
#' 
#' @param agents Agent data frame
#' @return Numeric matrix with agent parameters
create_agent_parameter_matrix <- function(agents) {
  # Convert relevant agent parameters to matrix format
  matrix(c(
    agents$battery_capacity,
    agents$charging_power,
    agents$efficiency,
    agents$daily_distance,
    as.numeric(agents$home_charging),
    as.numeric(agents$work_charging),
    agents$soc_start_threshold,
    agents$soc_end_threshold,
    agents$convenience_factor,
    agents$time_flexibility
  ), nrow = nrow(agents), ncol = 10, byrow = FALSE)
}

#' Generate GPU Random Parameters
#' 
#' Generates random parameters for scenario simulation on GPU
#' 
#' @param scenario Scenario configuration
#' @param config Global configuration
#' @return Matrix of random parameters
generate_gpu_random_parameters <- function(scenario, config) {
  n_agents <- nrow(scenario$agents)
  n_days <- scenario$days
  
  # Generate random numbers for charging decisions and timing
  random_matrix <- matrix(
    runif(n_agents * n_days * 10),  # 10 random numbers per agent per day
    nrow = n_agents,
    ncol = n_days * 10
  )
  
  return(random_matrix)
}

#' Compute GPU Demand Profile
#' 
#' Computes demand profile using GPU matrix operations
#' 
#' @param gpu_agents GPU matrix with agent parameters
#' @param gpu_random GPU matrix with random parameters
#' @param config Configuration parameters
#' @return GPU vector with demand profile
compute_gpu_demand_profile <- function(gpu_agents, gpu_random, config) {
  time_steps <- config$simulation$days * (24 * 60 / config$simulation$time_resolution)
  n_agents <- nrow(gpu_agents)
  
  # Initialize demand profile
  demand_profile <- create_gpu_matrix(0, nrow = 1, ncol = time_steps)
  
  # Vectorized computation of charging patterns
  # This is a simplified version - full implementation would include
  # sophisticated behavioral modeling and optimization
  
  # Home charging probability matrix
  home_charging_prob <- gpu_agents[, 5] * 0.8  # Column 5 is home_charging flag
  
  # Work charging probability matrix  
  work_charging_prob <- gpu_agents[, 6] * 0.3  # Column 6 is work_charging flag
  
  # Charging power matrix
  charging_power <- gpu_agents[, 2]  # Column 2 is charging_power
  
  # Time-based demand calculation using matrix operations
  for (time_step in 1:time_steps) {
    hour_of_day <- ((time_step - 1) * config$simulation$time_resolution / 60) %% 24
    
    # Peak home charging hours (evening)
    home_factor <- ifelse(hour_of_day >= 18 & hour_of_day <= 23, 1.5, 0.3)
    
    # Peak work charging hours (morning/midday)
    work_factor <- ifelse(hour_of_day >= 9 & hour_of_day <= 15, 1.2, 0.1)
    
    # Calculate concurrent charging
    home_demand <- home_charging_prob * charging_power * home_factor
    work_demand <- work_charging_prob * charging_power * work_factor
    
    # Sum total demand for this time step
    total_step_demand <- sum(home_demand + work_demand)
    demand_profile[1, time_step] <- total_step_demand
  }
  
  return(as.vector(demand_profile))
}

#' GPU Matrix Multiplication
#' 
#' Performs optimized matrix multiplication on GPU
#' 
#' @param A First matrix (GPU or CPU)
#' @param B Second matrix (GPU or CPU)
#' @param transfer_result Logical: transfer result to CPU
#' @return Matrix multiplication result
gpu_matrix_multiply <- function(A, B, transfer_result = TRUE) {
  if (!gpu_available) {
    return(A %*% B)
  }
  
  tryCatch({
    # Ensure matrices are on GPU
    if (!inherits(A, "gpu.matrix")) {
      A <- create_gpu_matrix(A)
    }
    if (!inherits(B, "gpu.matrix")) {
      B <- create_gpu_matrix(B)
    }
    
    # Perform multiplication
    result <- A %*% B
    
    # Transfer back to CPU if requested
    if (transfer_result) {
      return(as.matrix(result))
    } else {
      return(result)
    }
    
  }, error = function(e) {
    warning("GPU matrix multiplication failed, using CPU: ", e$message)
    return(as.matrix(A) %*% as.matrix(B))
  })
}

#' GPU Memory Management
#' 
#' Monitors and manages GPU memory usage
#' 
#' @return List with memory information
monitor_gpu_memory <- function() {
  if (!gpu_available) {
    return(list(available = FALSE))
  }
  
  tryCatch({
    memory_info <- gpu.memory()
    
    return(list(
      available = TRUE,
      total = memory_info$Total,
      free = memory_info$Free,
      used = memory_info$Used,
      utilization = memory_info$Used / memory_info$Total * 100
    ))
  }, error = function(e) {
    return(list(
      available = FALSE,
      error = e$message
    ))
  })
}

#' Clear GPU Memory
#' 
#' Clears GPU memory and performs garbage collection
#' 
#' @param verbose Logical: print status messages
clear_gpu_memory <- function(verbose = TRUE) {
  if (!gpu_available) {
    if (verbose) cat("GPU not available for memory clearing\n")
    return(FALSE)
  }
  
  tryCatch({
    # Clear GPU memory
    gpu.memory.clear()
    
    # R garbage collection
    gc()
    
    if (verbose) {
      memory_info <- monitor_gpu_memory()
      if (memory_info$available) {
        cat(sprintf("🧹 GPU memory cleared. Free: %.1f GB\n", 
                   memory_info$free / 1024^3))
      }
    }
    
    return(TRUE)
  }, error = function(e) {
    if (verbose) cat("Failed to clear GPU memory:", e$message, "\n")
    return(FALSE)
  })
}

#' Performance Benchmark
#' 
#' Benchmarks GPU vs CPU performance
#' 
#' @param matrix_size Size of test matrices
#' @param iterations Number of benchmark iterations
#' @return List with benchmark results
benchmark_gpu_performance <- function(matrix_size = 1000, iterations = 10) {
  if (!gpu_available) {
    return(list(
      gpu_available = FALSE,
      message = "GPU not available for benchmarking"
    ))
  }
  
  # Create test matrices
  A <- matrix(rnorm(matrix_size^2), nrow = matrix_size)
  B <- matrix(rnorm(matrix_size^2), nrow = matrix_size)
  
  # CPU benchmark
  cpu_times <- numeric(iterations)
  for (i in 1:iterations) {
    cpu_times[i] <- system.time({
      result_cpu <- A %*% B
    })[3]
  }
  
  # GPU benchmark
  gpu_times <- numeric(iterations)
  for (i in 1:iterations) {
    gpu_times[i] <- system.time({
      result_gpu <- gpu_matrix_multiply(A, B)
    })[3]
  }
  
  return(list(
    gpu_available = TRUE,
    matrix_size = matrix_size,
    iterations = iterations,
    cpu_mean_time = mean(cpu_times),
    gpu_mean_time = mean(gpu_times),
    speedup = mean(cpu_times) / mean(gpu_times),
    cpu_times = cpu_times,
    gpu_times = gpu_times
  ))
}

#' Fallback CPU Monte Carlo
#' 
#' CPU fallback when GPU processing fails
#' 
#' @param scenarios List of scenarios
#' @param config Configuration
#' @param progress_callback Progress function
#' @return Simulation results
run_cpu_monte_carlo_fallback <- function(scenarios, config, progress_callback) {
  # This would call the CPU version from parallel_processing.R
  # For now, return a placeholder
  warning("Using CPU fallback - implement parallel_processing.R functions")
  return(list())
}

# Export GPU functions
if (gpu_available) {
  cat("✅ GPU acceleration module loaded successfully\n")
} else {
  cat("ℹ️  GPU acceleration module loaded (GPU not available)\n")
}