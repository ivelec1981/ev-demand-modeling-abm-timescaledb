# ==============================================================================
# parallel_processing.R - Parallel Processing Module for EV Demand Modeling
# ==============================================================================
#
# This module provides CPU-based parallel processing capabilities using
# multiple R parallel processing frameworks including parallel, future,
# and foreach. It handles load balancing, progress reporting, and fault
# tolerance for large-scale simulations.
#
# Author: Iván Sánchez-Loor, Manuel Ayala-Chauvin
# Institution: Universidad Indoamérica - SISAu Research Group
# ==============================================================================

# Load required libraries
suppressPackageStartupMessages({
  library(parallel)
  library(doParallel)
  library(foreach)
  library(future)
  library(future.apply)
  library(furrr)
  library(progressr)
  library(tictoc)
})

# Global variables for cluster management
.parallel_cluster <- NULL
.parallel_strategy <- NULL

#' Setup Parallel Processing
#' 
#' Initializes parallel processing backend with optimal configuration
#' 
#' @param n_cores Number of CPU cores to use
#' @param strategy Parallel strategy: "cluster", "multicore", "future"
#' @param verbose Logical: print setup information
#' @return Logical: TRUE if successful
setup_parallel_processing <- function(n_cores = NULL, 
                                     strategy = "auto", 
                                     verbose = TRUE) {
  
  if (verbose) cat("⚙️ Setting up parallel processing...\n")
  
  # Determine optimal number of cores
  if (is.null(n_cores)) {
    available_cores <- parallel::detectCores()
    n_cores <- max(1, available_cores - 1)  # Leave one core free
  }
  
  # Validate core count
  n_cores <- min(n_cores, parallel::detectCores())
  n_cores <- max(1, n_cores)
  
  # Determine optimal strategy
  if (strategy == "auto") {
    if (.Platform$OS.type == "windows") {
      strategy <- "cluster"  # Windows doesn't support forking
    } else {
      strategy <- "multicore"  # Unix systems can use forking
    }
  }
  
  .parallel_strategy <<- strategy
  
  tryCatch({
    # Setup based on strategy
    if (strategy == "cluster") {
      setup_cluster_parallel(n_cores, verbose)
    } else if (strategy == "multicore") {
      setup_multicore_parallel(n_cores, verbose)
    } else if (strategy == "future") {
      setup_future_parallel(n_cores, verbose)
    } else {
      stop("Unknown parallel strategy: ", strategy)
    }
    
    if (verbose) {
      cat(sprintf("✅ Parallel processing initialized\n"))
      cat(sprintf("   🖥️  Strategy: %s\n", strategy))
      cat(sprintf("   🔧 Cores: %d/%d\n", n_cores, parallel::detectCores()))
    }
    
    return(TRUE)
    
  }, error = function(e) {
    if (verbose) cat("❌ Parallel setup failed:", e$message, "\n")
    return(FALSE)
  })
}

#' Setup Cluster-based Parallel Processing
#' 
#' Creates a cluster for parallel processing (works on all platforms)
#' 
#' @param n_cores Number of cores
#' @param verbose Verbose output
setup_cluster_parallel <- function(n_cores, verbose) {
  # Create cluster
  .parallel_cluster <<- parallel::makeCluster(n_cores)
  
  # Register cluster for foreach
  doParallel::registerDoParallel(.parallel_cluster)
  
  # Load required libraries on cluster nodes
  cluster_libraries <- c(
    "dplyr", "tidyr", "lubridate", "MASS", "truncnorm"
  )
  
  parallel::clusterEvalQ(.parallel_cluster, {
    suppressPackageStartupMessages({
      library(dplyr)
      library(tidyr) 
      library(lubridate)
      library(MASS)
      library(truncnorm)
    })
  })
  
  if (verbose) cat("   🔗 Cluster created with", n_cores, "workers\n")
}

#' Setup Multicore Parallel Processing
#' 
#' Uses forking for parallel processing (Unix-like systems only)
#' 
#' @param n_cores Number of cores
#' @param verbose Verbose output
setup_multicore_parallel <- function(n_cores, verbose) {
  # Register multicore backend for foreach
  doParallel::registerDoParallel(cores = n_cores)
  
  if (verbose) cat("   🍴 Multicore processing enabled with", n_cores, "cores\n")
}

#' Setup Future-based Parallel Processing
#' 
#' Uses the future framework for parallel processing
#' 
#' @param n_cores Number of cores
#' @param verbose Verbose output
setup_future_parallel <- function(n_cores, verbose) {
  # Set up future strategy
  if (.Platform$OS.type == "windows") {
    future::plan(future::multisession, workers = n_cores)
  } else {
    future::plan(future::multicore, workers = n_cores)
  }
  
  if (verbose) cat("   🔮 Future-based processing enabled with", n_cores, "workers\n")
}

#' Parallel Monte Carlo Simulation
#' 
#' Executes Monte Carlo runs in parallel with progress reporting
#' 
#' @param scenarios List of simulation scenarios
#' @param simulation_function Function to execute for each scenario
#' @param progress_reporting Logical: enable progress reporting
#' @param chunk_size Number of scenarios per chunk
#' @return List of simulation results
parallel_monte_carlo <- function(scenarios, 
                                simulation_function,
                                progress_reporting = TRUE,
                                chunk_size = NULL) {
  
  n_scenarios <- length(scenarios)
  
  if (is.null(chunk_size)) {
    # Determine optimal chunk size based on number of cores
    n_workers <- get_n_workers()
    chunk_size <- max(1, ceiling(n_scenarios / (n_workers * 4)))
  }
  
  if (progress_reporting) {
    cat(sprintf("🎲 Running %s Monte Carlo scenarios in parallel...\n", 
               format(n_scenarios, big.mark = ",")))
    cat(sprintf("   📦 Chunk size: %d\n", chunk_size))
  }
  
  # Execute based on parallel strategy
  if (.parallel_strategy == "future") {
    results <- parallel_monte_carlo_future(
      scenarios, 
      simulation_function, 
      progress_reporting,
      chunk_size
    )
  } else {
    results <- parallel_monte_carlo_foreach(
      scenarios, 
      simulation_function, 
      progress_reporting,
      chunk_size
    )
  }
  
  return(results)
}

#' Monte Carlo with Future Framework
#' 
#' Uses future framework for parallel execution
#' 
#' @param scenarios Simulation scenarios
#' @param simulation_function Simulation function
#' @param progress_reporting Enable progress
#' @param chunk_size Chunk size
#' @return Results list
parallel_monte_carlo_future <- function(scenarios, simulation_function, 
                                       progress_reporting, chunk_size) {
  
  if (progress_reporting) {
    with_progress({
      p <- progressr::progressor(steps = length(scenarios))
      
      results <- future.apply::future_lapply(
        scenarios,
        function(scenario) {
          result <- simulation_function(scenario)
          p()  # Update progress
          return(result)
        },
        future.seed = TRUE
      )
    })
  } else {
    results <- future.apply::future_lapply(
      scenarios,
      simulation_function,
      future.seed = TRUE
    )
  }
  
  return(results)
}

#' Monte Carlo with Foreach Framework
#' 
#' Uses foreach framework for parallel execution
#' 
#' @param scenarios Simulation scenarios
#' @param simulation_function Simulation function
#' @param progress_reporting Enable progress
#' @param chunk_size Chunk size
#' @return Results list
parallel_monte_carlo_foreach <- function(scenarios, simulation_function,
                                        progress_reporting, chunk_size) {
  
  if (progress_reporting) {
    with_progress({
      p <- progressr::progressor(steps = length(scenarios))
      
      results <- foreach(
        scenario = scenarios,
        .packages = c("dplyr", "tidyr", "lubridate", "MASS", "truncnorm"),
        .combine = c,
        .multicombine = TRUE
      ) %dopar% {
        result <- simulation_function(scenario)
        p()  # Update progress
        return(list(result))
      }
    })
  } else {
    results <- foreach(
      scenario = scenarios,
      .packages = c("dplyr", "tidyr", "lubridate", "MASS", "truncnorm"),
      .combine = c,
      .multicombine = TRUE
    ) %dopar% {
      result <- simulation_function(scenario)
      return(list(result))
    }
  }
  
  return(results)
}

#' Parallel Matrix Operations
#' 
#' Performs large matrix operations in parallel chunks
#' 
#' @param matrices List of matrices to process
#' @param operation Function to apply to each matrix
#' @param chunk_size Number of matrices per chunk
#' @return List of processed matrices
parallel_matrix_operations <- function(matrices, operation, chunk_size = NULL) {
  n_matrices <- length(matrices)
  
  if (is.null(chunk_size)) {
    n_workers <- get_n_workers()
    chunk_size <- max(1, ceiling(n_matrices / n_workers))
  }
  
  # Create chunks
  chunks <- split(matrices, ceiling(seq_along(matrices) / chunk_size))
  
  # Process chunks in parallel
  if (.parallel_strategy == "future") {
    results <- future.apply::future_lapply(chunks, function(chunk) {
      lapply(chunk, operation)
    })
  } else {
    results <- foreach(
      chunk = chunks,
      .combine = c,
      .multicombine = TRUE
    ) %dopar% {
      lapply(chunk, operation)
    }
  }
  
  # Flatten results
  results <- do.call(c, results)
  return(results)
}

#' Parallel Data Processing
#' 
#' Processes large datasets in parallel chunks
#' 
#' @param data Data frame or list to process
#' @param processing_function Function to apply to each chunk
#' @param chunk_size Size of each chunk
#' @param combine_function Function to combine results
#' @return Processed data
parallel_data_processing <- function(data, 
                                   processing_function,
                                   chunk_size = NULL,
                                   combine_function = rbind) {
  
  if (is.data.frame(data)) {
    n_rows <- nrow(data)
    if (is.null(chunk_size)) {
      n_workers <- get_n_workers()
      chunk_size <- max(1000, ceiling(n_rows / n_workers))
    }
    
    # Create row indices for chunks
    chunk_indices <- split(1:n_rows, ceiling(seq_len(n_rows) / chunk_size))
    
    # Process chunks
    if (.parallel_strategy == "future") {
      results <- future.apply::future_lapply(chunk_indices, function(indices) {
        chunk_data <- data[indices, , drop = FALSE]
        processing_function(chunk_data)
      })
    } else {
      results <- foreach(
        indices = chunk_indices,
        .combine = combine_function,
        .multicombine = TRUE,
        .packages = c("dplyr", "tidyr")
      ) %dopar% {
        chunk_data <- data[indices, , drop = FALSE]
        processing_function(chunk_data)
      }
    }
  } else if (is.list(data)) {
    # Process list elements
    if (.parallel_strategy == "future") {
      results <- future.apply::future_lapply(data, processing_function)
    } else {
      results <- foreach(
        item = data,
        .combine = combine_function,
        .multicombine = TRUE
      ) %dopar% {
        processing_function(item)
      }
    }
  } else {
    stop("Data must be a data frame or list")
  }
  
  return(results)
}

#' Load Balanced Execution
#' 
#' Distributes work with load balancing
#' 
#' @param tasks List of tasks to execute
#' @param task_function Function to execute each task
#' @param load_balancing Logical: enable load balancing
#' @return Task results
load_balanced_execution <- function(tasks, task_function, load_balancing = TRUE) {
  n_tasks <- length(tasks)
  n_workers <- get_n_workers()
  
  if (load_balancing && n_tasks > n_workers) {
    # Use dynamic scheduling for load balancing
    if (.parallel_strategy == "future") {
      # Future framework handles load balancing automatically
      results <- future.apply::future_lapply(tasks, task_function)
    } else {
      # Use foreach with .scheduling for load balancing
      results <- foreach(
        task = tasks,
        .scheduling = "dynamic",
        .combine = c,
        .multicombine = TRUE
      ) %dopar% {
        result <- task_function(task)
        return(list(result))
      }
    }
  } else {
    # Simple parallel execution
    results <- parallel_monte_carlo(tasks, task_function, progress_reporting = FALSE)
  }
  
  return(results)
}

#' Performance Monitoring
#' 
#' Monitors parallel processing performance
#' 
#' @param n_tasks Number of tasks to benchmark
#' @param task_duration Average task duration (seconds)
#' @return Performance metrics
benchmark_parallel_performance <- function(n_tasks = 1000, task_duration = 0.01) {
  cat("📊 Benchmarking parallel processing performance...\n")
  
  # Create dummy tasks
  dummy_task <- function(x) {
    Sys.sleep(task_duration)  # Simulate work
    return(x^2)
  }
  
  tasks <- 1:n_tasks
  
  # Sequential benchmark
  cat("   🔄 Running sequential benchmark...\n")
  tictoc::tic()
  sequential_results <- lapply(tasks, dummy_task)
  sequential_time <- tictoc::toc(quiet = TRUE)
  
  # Parallel benchmark
  cat("   ⚡ Running parallel benchmark...\n")
  tictoc::tic()
  if (.parallel_strategy == "future") {
    parallel_results <- future.apply::future_lapply(tasks, dummy_task)
  } else {
    parallel_results <- foreach(task = tasks, .combine = c) %dopar% {
      list(dummy_task(task))
    }
  }
  parallel_time <- tictoc::toc(quiet = TRUE)
  
  # Calculate metrics
  sequential_duration <- sequential_time$toc - sequential_time$tic
  parallel_duration <- parallel_time$toc - parallel_time$tic
  speedup <- sequential_duration / parallel_duration
  efficiency <- speedup / get_n_workers()
  
  results <- list(
    n_tasks = n_tasks,
    n_workers = get_n_workers(),
    sequential_time = sequential_duration,
    parallel_time = parallel_duration,
    speedup = speedup,
    efficiency = efficiency,
    tasks_per_second_sequential = n_tasks / sequential_duration,
    tasks_per_second_parallel = n_tasks / parallel_duration
  )
  
  # Print results
  cat("\n📈 Performance Results:\n")
  cat(sprintf("   ⏱️  Sequential time: %.2f seconds\n", sequential_duration))
  cat(sprintf("   ⚡ Parallel time: %.2f seconds\n", parallel_duration))
  cat(sprintf("   🚀 Speedup: %.2fx\n", speedup))
  cat(sprintf("   📊 Efficiency: %.1f%%\n", efficiency * 100))
  cat(sprintf("   ⚡ Tasks/sec (parallel): %.1f\n", results$tasks_per_second_parallel))
  
  return(results)
}

#' Get Number of Workers
#' 
#' Returns the number of parallel workers currently configured
#' 
#' @return Integer: number of workers
get_n_workers <- function() {
  if (.parallel_strategy == "cluster" && !is.null(.parallel_cluster)) {
    return(length(.parallel_cluster))
  } else if (.parallel_strategy == "multicore") {
    return(foreach::getDoParWorkers())
  } else if (.parallel_strategy == "future") {
    return(future::nbrOfWorkers())
  } else {
    return(1)  # Sequential fallback
  }
}

#' Check Parallel Status
#' 
#' Provides information about parallel processing setup
#' 
#' @return List with parallel processing status
check_parallel_status <- function() {
  status <- list(
    strategy = .parallel_strategy %||% "none",
    workers = get_n_workers(),
    cluster_active = !is.null(.parallel_cluster),
    foreach_backend = foreach::getDoParName(),
    future_plan = if(requireNamespace("future", quietly = TRUE)) class(future::plan())[1] else "none"
  )
  
  return(status)
}

#' Memory-Aware Parallel Processing
#' 
#' Adjusts parallel processing based on available memory
#' 
#' @param data_size_gb Estimated data size in GB
#' @param memory_limit_gb Memory limit in GB
#' @return Recommended number of workers
adjust_workers_for_memory <- function(data_size_gb, memory_limit_gb = 8) {
  available_cores <- parallel::detectCores()
  
  # Estimate memory per worker
  memory_per_worker <- data_size_gb * 1.5  # Include overhead
  max_workers_by_memory <- floor(memory_limit_gb / memory_per_worker)
  
  # Use minimum of memory-constrained and CPU-constrained workers
  recommended_workers <- min(
    max_workers_by_memory,
    max(1, available_cores - 1)
  )
  
  cat(sprintf("💾 Memory-aware worker adjustment:\n"))
  cat(sprintf("   📊 Data size: %.2f GB\n", data_size_gb))
  cat(sprintf("   💾 Memory limit: %.2f GB\n", memory_limit_gb))
  cat(sprintf("   🖥️  Available cores: %d\n", available_cores))
  cat(sprintf("   ⚙️  Recommended workers: %d\n", recommended_workers))
  
  return(recommended_workers)
}

#' Cleanup Parallel Resources
#' 
#' Properly shuts down parallel processing resources
cleanup_parallel_processing <- function() {
  if (!is.null(.parallel_cluster)) {
    parallel::stopCluster(.parallel_cluster)
    .parallel_cluster <<- NULL
    cat("🔌 Parallel cluster stopped\n")
  }
  
  # Reset foreach backend
  foreach::registerDoSEQ()
  
  # Reset future plan
  if (requireNamespace("future", quietly = TRUE)) {
    future::plan(future::sequential)
  }
  
  .parallel_strategy <<- NULL
  
  cat("🧹 Parallel processing cleanup completed\n")
}

# Automatic cleanup on package unload
.onUnload <- function(libpath) {
  cleanup_parallel_processing()
}

# Helper function for null coalescing
`%||%` <- function(a, b) if (is.null(a)) b else a

cat("⚡ Parallel processing module loaded successfully\n")