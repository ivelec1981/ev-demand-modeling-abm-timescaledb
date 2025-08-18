# ==============================================================================
# real_data_loader.R - Cargador de Datos Reales para EV Demand Modeling
# ==============================================================================
#
# Este módulo conecta con datos reales de consumo eléctrico de EEQ y otros
# proveedores para calibrar y validar las simulaciones de vehículos eléctricos.
#
# Autor: Iván Sánchez-Loor, Manuel Ayala-Chauvin
# Institución: Universidad Indoamérica - Grupo SISAu
# ==============================================================================

library(dplyr)
library(readr)
library(readxl)
library(lubridate)
library(DBI)
library(RPostgres)

#' Cargar Perfiles de Carga Reales de EEQ
#' 
#' Carga los datos reales de perfiles de carga desde el directorio EEQ
#' 
#' @param data_path Ruta a los datos consolidados de EEQ
#' @param pattern Patrón de archivos a cargar
#' @param limit_files Número máximo de archivos a procesar (NULL = todos)
#' @return Data frame con perfiles de carga normalizados
load_eeq_consumption_profiles <- function(
    data_path = "C:/Users/LEGION/Maestria BigData/Trabajo Titulacion/EEQ/ConsolidadoPerfiles",
    pattern = "*.csv",
    limit_files = NULL
) {
  
  cat("📁 Cargando perfiles de consumo real de EEQ...\n")
  
  # Buscar todos los archivos CSV
  csv_files <- list.files(data_path, pattern = "*.csv$", 
                         full.names = TRUE, recursive = TRUE)
  
  if (length(csv_files) == 0) {
    stop("No se encontraron archivos CSV en: ", data_path)
  }
  
  # Limitar archivos si se especifica
  if (!is.null(limit_files)) {
    csv_files <- head(csv_files, limit_files)
  }
  
  cat(sprintf("   📊 Procesando %d archivos...\n", length(csv_files)))
  
  # Cargar y procesar archivos
  profiles_list <- list()
  
  for (i in seq_along(csv_files)) {
    file_path <- csv_files[i]
    
    tryCatch({
      # Leer archivo
      profile_data <- read_csv(file_path, show_col_types = FALSE)
      
      # Extraer información del nombre del archivo
      file_name <- basename(file_path)
      
      # Extraer ID del medidor y fecha del nombre del archivo
      meter_info <- extract_meter_info(file_name)
      
      # Procesar datos del perfil
      processed_profile <- process_profile_data(profile_data, meter_info)
      
      if (nrow(processed_profile) > 0) {
        profiles_list[[i]] <- processed_profile
        
        if (i %% 50 == 0) {
          cat(sprintf("   ✅ Procesados %d/%d archivos\n", i, length(csv_files)))
        }
      }
      
    }, error = function(e) {
      warning(sprintf("Error procesando archivo %s: %s", file_name, e$message))
    })
  }
  
  # Combinar todos los perfiles
  combined_profiles <- bind_rows(profiles_list)
  
  cat(sprintf("✅ Cargados %d perfiles de %d medidores\n", 
             nrow(combined_profiles), 
             length(unique(combined_profiles$meter_id))))
  
  return(combined_profiles)
}

#' Extraer Información del Medidor desde Nombre de Archivo
#' 
#' Extrae ID del medidor, fecha y otros metadatos del nombre del archivo
#' 
#' @param file_name Nombre del archivo
#' @return Lista con información extraída
extract_meter_info <- function(file_name) {
  # Patrones comunes en archivos EEQ:
  # monthly_load_profile-1117823-20230101.csv
  # PerfilCarga 1002475618_200015675537 (1002475618_20250515).csv
  
  meter_id <- NA
  date_str <- NA
  customer_id <- NA
  
  # Patrón 1: monthly_load_profile-METERID-YYYYMMDD.csv
  if (grepl("monthly_load_profile", file_name)) {
    matches <- regmatches(file_name, regexec("monthly_load_profile-(\\d+)-(\\d{8})", file_name))[[1]]
    if (length(matches) == 3) {
      meter_id <- matches[2]
      date_str <- matches[3]
    }
  }
  
  # Patrón 2: PerfilCarga CUSTOMERID_METERID (CUSTOMERID_YYYYMMDD).csv
  else if (grepl("PerfilCarga", file_name)) {
    # Extraer customer_id y fecha
    matches <- regmatches(file_name, regexec("PerfilCarga\\s+(\\d+)_.+\\((\\d+)_(\\d{8})\\)", file_name))[[1]]
    if (length(matches) == 4) {
      customer_id <- matches[2]
      meter_id <- matches[2] # Usar customer_id como meter_id
      date_str <- matches[4]
    }
  }
  
  # Convertir fecha si se encontró
  profile_date <- NA
  if (!is.na(date_str)) {
    tryCatch({
      profile_date <- as.Date(date_str, format = "%Y%m%d")
    }, error = function(e) {
      profile_date <- NA
    })
  }
  
  return(list(
    meter_id = meter_id,
    customer_id = customer_id,
    profile_date = profile_date,
    file_name = file_name
  ))
}

#' Procesar Datos del Perfil de Carga
#' 
#' Limpia y normaliza los datos del perfil de carga
#' 
#' @param profile_data Datos crudos del perfil
#' @param meter_info Información del medidor
#' @return Data frame procesado
process_profile_data <- function(profile_data, meter_info) {
  # Saltear filas de error de PHP si existen
  if (any(grepl("Warning|Error", names(profile_data)) | 
          grepl("Warning|Error", as.character(profile_data[1,]), na.rm = TRUE))) {
    # Buscar primera fila con datos válidos
    valid_row <- which(!grepl("Warning|Error|<b>", 
                             apply(profile_data, 1, paste, collapse = ""), 
                             ignore.case = TRUE))[1]
    if (!is.na(valid_row) && valid_row > 1) {
      profile_data <- profile_data[valid_row:nrow(profile_data), ]
    }
  }
  
  # Identificar columnas de tiempo y consumo
  # Buscar columnas que puedan ser timestamps o horas
  time_cols <- grep("time|hora|fecha|timestamp", names(profile_data), ignore.case = TRUE)
  consumption_cols <- grep("consumption|consumo|kwh|demand|demanda", names(profile_data), ignore.case = TRUE)
  
  # Si no hay columnas identificadas claramente, usar heurísticas
  if (length(time_cols) == 0) {
    # Buscar columnas numéricas que puedan ser horas (0-23)
    numeric_cols <- sapply(profile_data, is.numeric)
    for (col in which(numeric_cols)) {
      if (all(profile_data[[col]] >= 0 & profile_data[[col]] <= 23, na.rm = TRUE)) {
        time_cols <- c(time_cols, col)
        break
      }
    }
  }
  
  if (length(consumption_cols) == 0) {
    # Buscar columnas numéricas con valores de consumo típicos
    numeric_cols <- sapply(profile_data, is.numeric)
    consumption_cols <- which(numeric_cols)
    consumption_cols <- setdiff(consumption_cols, time_cols)
  }
  
  # Crear estructura de datos normalizada
  if (length(time_cols) > 0 && length(consumption_cols) > 0) {
    processed_data <- data.frame(
      meter_id = meter_info$meter_id,
      customer_id = meter_info$customer_id %||% meter_info$meter_id,
      profile_date = meter_info$profile_date,
      timestamp = if (length(time_cols) > 0) profile_data[[time_cols[1]]] else NA,
      consumption_kwh = if (length(consumption_cols) > 0) profile_data[[consumption_cols[1]]] else NA,
      file_source = meter_info$file_name,
      stringsAsFactors = FALSE
    )
    
    # Filtrar filas válidas
    processed_data <- processed_data[!is.na(processed_data$consumption_kwh) & 
                                   processed_data$consumption_kwh >= 0, ]
    
    return(processed_data)
  }
  
  return(data.frame()) # Retornar data frame vacío si no se puede procesar
}

#' Calibrar Simulación con Datos Reales
#' 
#' Usa datos reales de EEQ para calibrar parámetros del simulador
#' 
#' @param real_profiles Perfiles de carga reales
#' @param simulation_config Configuración de simulación base
#' @return Configuración calibrada
calibrate_with_real_data <- function(real_profiles, simulation_config = NULL) {
  
  cat("🎯 Calibrando simulación con datos reales...\n")
  
  if (is.null(simulation_config)) {
    source("src/ev_simulator_final.R")
    simulation_config <- get_default_config()
  }
  
  # Análisis estadístico de datos reales
  consumption_stats <- real_profiles %>%
    group_by(meter_id) %>%
    summarise(
      avg_consumption = mean(consumption_kwh, na.rm = TRUE),
      max_consumption = max(consumption_kwh, na.rm = TRUE),
      min_consumption = min(consumption_kwh, na.rm = TRUE),
      consumption_std = sd(consumption_kwh, na.rm = TRUE),
      n_readings = n(),
      .groups = 'drop'
    ) %>%
    filter(!is.na(avg_consumption) & avg_consumption > 0)
  
  if (nrow(consumption_stats) == 0) {
    warning("No se pudieron obtener estadísticas válidas de los datos reales")
    return(simulation_config)
  }
  
  # Calibrar parámetros basados en datos reales
  # 1. Estimar capacidades de batería basadas en consumo
  avg_daily_consumption <- mean(consumption_stats$avg_consumption, na.rm = TRUE) * 24 # kWh/día
  
  # Suponer que VE consume 6-8 km/kWh y recorre 40-60 km/día
  estimated_daily_ev_consumption <- 40 / 7  # ~6 kWh/día por VE
  
  # Ajustar número de vehículos para que coincida con el consumo observado
  estimated_vehicles <- round(avg_daily_consumption / estimated_daily_ev_consumption)
  
  # 2. Calibrar patrones temporales
  if ("timestamp" %in% names(real_profiles) && any(!is.na(real_profiles$timestamp))) {
    hourly_pattern <- real_profiles %>%
      filter(!is.na(timestamp)) %>%
      mutate(hour = timestamp %% 24) %>%
      group_by(hour) %>%
      summarise(avg_consumption = mean(consumption_kwh, na.rm = TRUE), .groups = 'drop') %>%
      arrange(hour)
    
    peak_hour <- hourly_pattern$hour[which.max(hourly_pattern$avg_consumption)]
    valley_hour <- hourly_pattern$hour[which.min(hourly_pattern$avg_consumption)]
    
    # Ajustar horarios de carga en configuración
    simulation_config$charging$charging_start_times$home$mean <- peak_hour
    simulation_config$charging$charging_start_times$work$mean <- peak_hour - 8
  }
  
  # 3. Actualizar configuración calibrada
  simulation_config$vehicles$num_vehicles <- min(estimated_vehicles, 50000) # Máximo práctico
  
  # 4. Calcular factor de escalamiento
  scaling_factor <- avg_daily_consumption / (simulation_config$vehicles$num_vehicles * estimated_daily_ev_consumption)
  
  cat(sprintf("📊 Estadísticas de calibración:\n"))
  cat(sprintf("   📈 Consumo promedio diario observado: %.2f kWh\n", avg_daily_consumption))
  cat(sprintf("   🚗 Vehículos estimados necesarios: %d\n", simulation_config$vehicles$num_vehicles))
  cat(sprintf("   ⚖️  Factor de escalamiento: %.3f\n", scaling_factor))
  cat(sprintf("   🕐 Hora pico estimada: %02d:00\n", peak_hour %||% 19))
  
  # Agregar metadatos de calibración
  simulation_config$calibration <- list(
    real_data_source = "EEQ_ConsolidadoPerfiles",
    calibration_date = Sys.Date(),
    meters_analyzed = nrow(consumption_stats),
    avg_daily_consumption_kwh = avg_daily_consumption,
    scaling_factor = scaling_factor,
    peak_hour = peak_hour %||% 19,
    valley_hour = valley_hour %||% 4
  )
  
  return(simulation_config)
}

#' Validar Simulación contra Datos Reales
#' 
#' Compara resultados de simulación con datos reales para validación
#' 
#' @param simulation_results Resultados de simulación
#' @param real_profiles Perfiles reales para comparación
#' @return Métricas de validación
validate_simulation_against_real_data <- function(simulation_results, real_profiles) {
  
  cat("✅ Validando simulación contra datos reales...\n")
  
  # Extraer datos simulados
  if (length(simulation_results$results) > 0) {
    sim_data <- simulation_results$results[[1]]  # Usar primer run Monte Carlo
    simulated_demand <- sim_data$total_demand_adjusted
  } else {
    stop("No hay resultados de simulación para validar")
  }
  
  # Procesar datos reales para comparación
  real_consumption <- real_profiles %>%
    filter(!is.na(consumption_kwh)) %>%
    arrange(profile_date, timestamp) %>%
    pull(consumption_kwh)
  
  # Alinear longitudes para comparación
  min_length <- min(length(simulated_demand), length(real_consumption))
  if (min_length < 100) {
    warning("Pocos puntos de datos para validación confiable")
  }
  
  sim_aligned <- simulated_demand[1:min_length]
  real_aligned <- real_consumption[1:min_length]
  
  # Calcular métricas de validación
  mae <- mean(abs(sim_aligned - real_aligned), na.rm = TRUE)
  rmse <- sqrt(mean((sim_aligned - real_aligned)^2, na.rm = TRUE))
  mape <- mean(abs((sim_aligned - real_aligned) / real_aligned), na.rm = TRUE) * 100
  
  # Correlación
  correlation <- cor(sim_aligned, real_aligned, use = "complete.obs")
  
  # Métricas adicionales
  sim_mean <- mean(sim_aligned, na.rm = TRUE)
  real_mean <- mean(real_aligned, na.rm = TRUE)
  bias <- sim_mean - real_mean
  
  validation_metrics <- list(
    mae = mae,
    rmse = rmse,
    mape = mape,
    correlation = correlation,
    bias = bias,
    sim_mean = sim_mean,
    real_mean = real_mean,
    data_points = min_length
  )
  
  cat(sprintf("📊 Métricas de validación:\n"))
  cat(sprintf("   📏 MAE: %.3f kW\n", mae))
  cat(sprintf("   📐 RMSE: %.3f kW\n", rmse))
  cat(sprintf("   📊 MAPE: %.2f%%\n", mape))
  cat(sprintf("   🔗 Correlación: %.3f\n", correlation))
  cat(sprintf("   ⚖️  Sesgo: %.3f kW\n", bias))
  
  return(validation_metrics)
}

# Helper function para null coalescing
`%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || is.na(a)) b else a

cat("📊 Módulo de carga de datos reales inicializado\n")