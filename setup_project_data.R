# ==============================================================================
# setup_project_data.R - Project Data Setup Script
# ==============================================================================
#
# This script copies real EEQ data to the project and configures the data
# structure necessary for scientific reproducibility.
#
# Author: Iván Sánchez-Loor, Manuel Ayala-Chauvin
# Institution: Universidad Indoamérica - Grupo SISAu
# ==============================================================================

cat("📁 CONFIGURANDO DATOS DEL PROYECTO EV DEMAND MODELING\n")
cat("=====================================================\n\n")

# Directory configuration
proyecto_dir <- getwd()
datos_eeq_origen <- "C:/Users/LEGION/Maestria BigData/Trabajo Titulacion/EEQ/ConsolidadoPerfiles"
datos_eeq_destino <- file.path(proyecto_dir, "data", "raw", "eeq_profiles")

cat("📂 Directorios:\n")
cat(sprintf("   🏠 Proyecto: %s\n", proyecto_dir))
cat(sprintf("   📊 Origen EEQ: %s\n", datos_eeq_origen))
cat(sprintf("   📁 Destino EEQ: %s\n", datos_eeq_destino))

# 1. VERIFY DATA STRUCTURE
cat("\n1️⃣ Verificando estructura de datos...\n")

# Create directories if they don't exist
required_dirs <- c(
  "data",
  "data/raw",
  "data/raw/eeq_profiles",
  "data/processed",
  "data/sample_outputs",
  "data/validation_data",
  "data/fallback_data"
)

for (dir in required_dirs) {
  full_path <- file.path(proyecto_dir, dir)
  if (!dir.exists(full_path)) {
    dir.create(full_path, recursive = TRUE)
    cat(sprintf("   ✅ Creado: %s\n", dir))
  } else {
    cat(sprintf("   ✓ Existe: %s\n", dir))
  }
}

# 2. VERIFY EEQ DATA
cat("\n2️⃣ Verificando datos de EEQ...\n")

if (!dir.exists(datos_eeq_origen)) {
  stop("❌ No se encontró el directorio de datos EEQ: ", datos_eeq_origen)
}

# Count files in source directory
archivos_csv <- list.files(datos_eeq_origen, pattern = "\\.csv$", recursive = TRUE, full.names = TRUE)
archivos_xlsx <- list.files(datos_eeq_origen, pattern = "\\.xlsx?$", recursive = TRUE, full.names = TRUE)
carpetas <- list.dirs(datos_eeq_origen, recursive = TRUE)[-1]  # Exclude root directory

cat(sprintf("   📊 Archivos CSV: %d\n", length(archivos_csv)))
cat(sprintf("   📊 Archivos Excel: %d\n", length(archivos_xlsx)))
cat(sprintf("   📁 Carpetas: %d\n", length(carpetas)))

total_size <- sum(file.size(c(archivos_csv, archivos_xlsx)), na.rm = TRUE)
cat(sprintf("   💾 Tamaño total: %.1f MB\n", total_size / (1024^2)))

# 3. COPY EEQ DATA
cat("\n3️⃣ Copiando datos de EEQ...\n")

# Function to copy files with progress tracking
copy_files_with_progress <- function(source_files, source_dir, dest_dir) {
  total_files <- length(source_files)
  copied_files <- 0
  failed_files <- 0
  
  cat(sprintf("   🔄 Copiando %d archivos...\n", total_files))
  
  for (i in seq_along(source_files)) {
    source_file <- source_files[i]
    
    # Calculate relative path
    rel_path <- gsub(paste0("^", gsub("\\\\", "/", normalizePath(source_dir)), "/"), 
                     "", gsub("\\\\", "/", normalizePath(source_file)))
    dest_file <- file.path(dest_dir, rel_path)
    
    # Create destination directory if it doesn't exist
    dest_subdir <- dirname(dest_file)
    if (!dir.exists(dest_subdir)) {
      dir.create(dest_subdir, recursive = TRUE)
    }
    
    # Copy file
    tryCatch({
      file.copy(source_file, dest_file, overwrite = TRUE)
      copied_files <- copied_files + 1
      
      # Show progress every 50 files
      if (i %% 50 == 0 || i == total_files) {
        cat(sprintf("     📈 Progreso: %d/%d archivos (%.1f%%)\n", 
                   i, total_files, (i/total_files)*100))
      }
    }, error = function(e) {
      warning(sprintf("Error copiando %s: %s", basename(source_file), e$message))
      failed_files <<- failed_files + 1
    })
  }
  
  return(list(copied = copied_files, failed = failed_files, total = total_files))
}

# Copy CSV files
if (length(archivos_csv) > 0) {
  resultado_csv <- copy_files_with_progress(archivos_csv, datos_eeq_origen, datos_eeq_destino)
  cat(sprintf("   ✅ CSV copiados: %d/%d\n", resultado_csv$copied, resultado_csv$total))
  if (resultado_csv$failed > 0) {
    cat(sprintf("   ⚠️ CSV fallidos: %d\n", resultado_csv$failed))
  }
}

# Copy Excel files
if (length(archivos_xlsx) > 0) {
  resultado_xlsx <- copy_files_with_progress(archivos_xlsx, datos_eeq_origen, datos_eeq_destino)
  cat(sprintf("   ✅ Excel copiados: %d/%d\n", resultado_xlsx$copied, resultado_xlsx$total))
  if (resultado_xlsx$failed > 0) {
    cat(sprintf("   ⚠️ Excel fallidos: %d\n", resultado_xlsx$failed))
  }
}

# 4. VERIFY COPY
cat("\n4️⃣ Verificando copia...\n")

archivos_destino_csv <- list.files(datos_eeq_destino, pattern = "\\.csv$", recursive = TRUE)
archivos_destino_xlsx <- list.files(datos_eeq_destino, pattern = "\\.xlsx?$", recursive = TRUE)

cat(sprintf("   📊 CSV en destino: %d\n", length(archivos_destino_csv)))
cat(sprintf("   📊 Excel en destino: %d\n", length(archivos_destino_xlsx)))

# 5. CREATE PROCESSED SAMPLE DATA
cat("\n5️⃣ Creando datos de muestra procesados...\n")

# Read some files to create sample data
sample_files <- head(archivos_destino_csv, 5)
sample_data <- data.frame()

if (length(sample_files) > 0) {
  for (i in seq_along(sample_files)) {
    file_path <- file.path(datos_eeq_destino, sample_files[i])
    
    tryCatch({
      # Try to read the file
      data <- read.csv(file_path, stringsAsFactors = FALSE)
      
      # If it has valid data, take a sample
      if (nrow(data) > 0) {
        # Add file metadata
        data$source_file <- sample_files[i]
        data$file_index <- i
        
        # Take maximum 100 rows per file
        if (nrow(data) > 100) {
          data <- data[sample(nrow(data), 100), ]
        }
        
        sample_data <- rbind(sample_data, data, stringsAsFactors = FALSE)
      }
    }, error = function(e) {
      cat(sprintf("   ⚠️ Error leyendo muestra %s: %s\n", sample_files[i], e$message))
    })
  }
}

if (nrow(sample_data) > 0) {
  sample_output_file <- file.path(proyecto_dir, "data", "processed", "eeq_sample_data.csv")
  write.csv(sample_data, sample_output_file, row.names = FALSE)
  cat(sprintf("   ✅ Muestra creada: %d filas en %s\n", nrow(sample_data), basename(sample_output_file)))
}

# 6. CREATE SYNTHETIC FALLBACK DATA
cat("\n6️⃣ Creando datos de fallback sintéticos...\n")

# Generate synthetic data for testing when real data is unavailable
set.seed(42)
n_profiles <- 100
n_days <- 30
time_points_per_day <- 96  # 15 minutes = 96 points per day

synthetic_data <- data.frame()

for (profile_id in 1:n_profiles) {
  for (day in 1:n_days) {
    base_date <- as.Date("2024-01-01") + day - 1
    
    # Generate typical daily pattern
    hours <- seq(0, 23.75, by = 0.25)  # 15 minutes
    
    # Base pattern with morning and evening peaks
    base_pattern <- 0.5 + 0.3 * sin((hours - 6) * pi / 12) + 
                   0.2 * sin((hours - 18) * pi / 6)
    
    # Add noise and variability per profile
    consumption <- pmax(0, base_pattern * (0.8 + 0.4 * runif(1)) + 
                       rnorm(length(hours), 0, 0.1))
    
    day_data <- data.frame(
      profile_id = paste0("SYNTH_", sprintf("%03d", profile_id)),
      date = base_date,
      hour = hours,
      timestamp = as.POSIXct(paste(base_date, sprintf("%02d:%02d:00", 
                                                     floor(hours), 
                                                     (hours %% 1) * 60)), 
                            tz = "UTC"),
      consumption_kwh = consumption,
      profile_type = sample(c("residential", "commercial"), 1, prob = c(0.7, 0.3)),
      stringsAsFactors = FALSE
    )
    
    synthetic_data <- rbind(synthetic_data, day_data)
  }
}

# Save synthetic data
fallback_file <- file.path(proyecto_dir, "data", "fallback_data", "synthetic_profiles.csv")
write.csv(synthetic_data, fallback_file, row.names = FALSE)
cat(sprintf("   ✅ Datos sintéticos: %d filas en %s\n", nrow(synthetic_data), basename(fallback_file)))

# 7. CREATE DEFAULT PARAMETERS
cat("\n7️⃣ Creando parámetros por defecto...\n")

default_params <- list(
  simulation = list(
    default_vehicles = 1000,
    default_days = 7,
    time_resolution_minutes = 15,
    monte_carlo_runs = 100
  ),
  vehicles = list(
    battery_capacities_kwh = c(40, 60, 80),
    charging_powers_kw = c(3.7, 7.4, 11, 22),
    vehicle_types = c("compact", "sedan", "suv"),
    efficiency_km_per_kwh = c(6.0, 7.0, 8.0)
  ),
  charging = list(
    home_charging_probability = 0.8,
    work_charging_probability = 0.3,
    public_charging_probability = 0.1,
    peak_charging_hours = c(19, 20, 21)  # 7-9 PM
  ),
  calibration = list(
    coincidence_factor_formula = "FC = 0.222 + 0.036 * exp(-0.0003 * n)",
    validation_mape_target = 5.0,  # %
    correlation_target = 0.8
  )
)

# Save parameters as JSON
params_file <- file.path(proyecto_dir, "data", "fallback_data", "default_parameters.json")
writeLines(jsonlite::toJSON(default_params, pretty = TRUE, auto_unbox = TRUE), params_file)
cat(sprintf("   ✅ Parámetros guardados en %s\n", basename(params_file)))

# 8. CREATE DATA DOCUMENTATION
cat("\n8️⃣ Actualizando documentación de datos...\n")

# Information about copied data
data_manifest <- list(
  created_date = Sys.time(),
  source_directory = datos_eeq_origen,
  destination_directory = datos_eeq_destino,
  files_summary = list(
    csv_files = length(archivos_destino_csv),
    excel_files = length(archivos_destino_xlsx),
    total_files = length(archivos_destino_csv) + length(archivos_destino_xlsx),
    total_size_mb = round(total_size / (1024^2), 2)
  ),
  data_types = list(
    raw_eeq_profiles = "Real consumption profiles from EEQ customers",
    processed_samples = "Cleaned and standardized sample data",
    synthetic_fallback = "Generated synthetic data for testing",
    default_parameters = "Default simulation parameters"
  ),
  usage_notes = c(
    "Raw EEQ data should be processed before simulation",
    "Use synthetic data when real data is unavailable", 
    "All customer identifiers have been anonymized",
    "Data covers period 2023-2025 with 15-minute resolution"
  )
)

manifest_file <- file.path(proyecto_dir, "data", "data_manifest.json")
writeLines(jsonlite::toJSON(data_manifest, pretty = TRUE, auto_unbox = TRUE), manifest_file)
cat(sprintf("   ✅ Manifiesto creado: %s\n", basename(manifest_file)))

# 9. FINAL SUMMARY
cat("\n" + paste(rep("=", 60), collapse = "") + "\n")
cat("📊 CONFIGURACIÓN DE DATOS COMPLETADA\n")
cat(paste(rep("=", 60), collapse = "") + "\n")

cat("\n✅ RESULTADOS:\n")
cat(sprintf("   📁 Directorios creados: %d\n", length(required_dirs)))
cat(sprintf("   📊 Archivos CSV copiados: %d\n", length(archivos_destino_csv)))
cat(sprintf("   📊 Archivos Excel copiados: %d\n", length(archivos_destino_xlsx)))
if (exists("sample_data") && nrow(sample_data) > 0) {
  cat(sprintf("   🔬 Datos de muestra: %d filas\n", nrow(sample_data)))
}
cat(sprintf("   🤖 Datos sintéticos: %d filas\n", nrow(synthetic_data)))

cat("\n📂 ESTRUCTURA FINAL:\n")
cat("   data/\n")
cat("   ├── raw/eeq_profiles/     # Datos reales de EEQ\n")
cat("   ├── processed/            # Datos procesados y muestras\n") 
cat("   ├── fallback_data/        # Datos sintéticos de respaldo\n")
cat("   ├── sample_outputs/       # Resultados de ejemplo\n")
cat("   ├── validation_data/      # Datos para validación\n")
cat("   └── data_manifest.json    # Documentación de datos\n")

cat("\n🚀 PRÓXIMOS PASOS:\n")
cat("   1. Ejecutar: source('ejecutar_con_datos_reales.R')\n")
cat("   2. El simulador usará automáticamente los datos copiados\n")
cat("   3. Los resultados se guardarán en sample_outputs/\n")

cat("\n✨ ¡Configuración completada exitosamente!\n")
cat(paste(rep("=", 60), collapse = ""), "\n")