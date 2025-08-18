# ==============================================================================
# ejecutar_con_datos_reales.R - Simulación EV con Datos Reales de EEQ
# ==============================================================================
#
# Este script ejecuta el simulador de demanda de VE usando datos reales
# de perfiles de carga de EEQ para calibración y validación.
#
# Autor: Iván Sánchez-Loor, Manuel Ayala-Chauvin
# ==============================================================================

# Limpiar entorno
rm(list = ls())

# Cambiar al directorio del proyecto
setwd("C:/Users/LEGION/Maestria BigData/Trabajo Titulacion/ev-demand-modeling-abm-timescaledb")

cat("🚀 SIMULACIÓN EV CON DATOS REALES DE EEQ\n")
cat("========================================\n\n")

# 1. CARGAR MÓDULOS NECESARIOS
cat("📚 Cargando módulos...\n")
source("src/ev_simulator_final.R")
source("src/real_data_loader.R")

# 2. CARGAR DATOS REALES DE EEQ
cat("\n📊 Cargando datos reales de EEQ...\n")

# Ruta a tus datos de EEQ (ajustar si es necesario)
ruta_eeq <- "C:/Users/LEGION/Maestria BigData/Trabajo Titulacion/EEQ/ConsolidadoPerfiles"

# Cargar perfiles (limitar a 50 archivos para prueba rápida)
perfiles_eeq <- load_eeq_consumption_profiles(
  data_path = ruta_eeq,
  limit_files = 50  # Cambiar a NULL para cargar todos los archivos
)

if (nrow(perfiles_eeq) == 0) {
  stop("❌ No se pudieron cargar datos de EEQ. Verificar ruta y archivos.")
}

cat(sprintf("✅ Cargados %d registros de %d medidores\n", 
           nrow(perfiles_eeq), 
           length(unique(perfiles_eeq$meter_id))))

# 3. CALIBRAR CONFIGURACIÓN CON DATOS REALES
cat("\n🎯 Calibrando simulación con datos reales...\n")

# Obtener configuración base
config_base <- get_default_config()

# Calibrar con datos reales de EEQ
config_calibrado <- calibrate_with_real_data(perfiles_eeq, config_base)

# Mostrar configuración calibrada
cat("\n📋 Configuración calibrada:\n")
cat(sprintf("   🚗 Vehículos: %d\n", config_calibrado$vehicles$num_vehicles))
cat(sprintf("   📅 Días: %d\n", config_calibrado$simulation$days))
cat(sprintf("   🎲 Corridas MC: %d\n", config_calibrado$simulation$monte_carlo_runs))
cat(sprintf("   🏠 Hora pico carga: %02d:00\n", config_calibrado$charging$charging_start_times$home$mean))

# 4. EJECUTAR SIMULACIÓN CALIBRADA
cat("\n⚡ Ejecutando simulación calibrada...\n")

inicio_sim <- Sys.time()

resultados_calibrados <- run_final_simulation(
  config = config_calibrado,
  processing_engine = "CPU",  # Cambiar a "GPU" si tienes CUDA
  save_to_db = FALSE,         # Cambiar a TRUE si tienes TimescaleDB
  verbose = TRUE
)

fin_sim <- Sys.time()
duracion <- as.numeric(fin_sim - inicio_sim, units = "mins")

cat(sprintf("✅ Simulación completada en %.1f minutos\n", duracion))

# 5. VALIDAR RESULTADOS CONTRA DATOS REALES
cat("\n🔍 Validando resultados...\n")

metricas_validacion <- validate_simulation_against_real_data(
  resultados_calibrados, 
  perfiles_eeq
)

# 6. GENERAR RESUMEN COMPLETO
cat("\n" + paste(rep("=", 60), collapse = "") + "\n")
cat("📊 RESUMEN DE RESULTADOS\n")
cat(paste(rep("=", 60), collapse = "") + "\n")

cat("\n📈 DATOS REALES DE EEQ:\n")
cat(sprintf("   📁 Archivos procesados: %d\n", length(unique(perfiles_eeq$file_source))))
cat(sprintf("   📊 Medidores analizados: %d\n", length(unique(perfiles_eeq$meter_id))))
cat(sprintf("   📅 Registros totales: %d\n", nrow(perfiles_eeq)))
cat(sprintf("   ⚡ Consumo promedio: %.2f kWh\n", mean(perfiles_eeq$consumption_kwh, na.rm = TRUE)))

cat("\n🎯 CALIBRACIÓN:\n")
if (!is.null(config_calibrado$calibration)) {
  cal <- config_calibrado$calibration
  cat(sprintf("   🚗 Vehículos estimados: %d\n", config_calibrado$vehicles$num_vehicles))
  cat(sprintf("   📊 Consumo diario observado: %.2f kWh\n", cal$avg_daily_consumption_kwh))
  cat(sprintf("   ⚖️  Factor escalamiento: %.3f\n", cal$scaling_factor))
  cat(sprintf("   🕐 Hora pico: %02d:00\n", cal$peak_hour))
}

cat("\n⚡ RESULTADOS SIMULACIÓN:\n")
cat(sprintf("   🚗 Vehículos simulados: %d\n", config_calibrado$vehicles$num_vehicles))
cat(sprintf("   📅 Días simulados: %d\n", config_calibrado$simulation$days))
cat(sprintf("   📊 Demanda promedio: %.2f kW\n", resultados_calibrados$summary$mean_daily_demand))
cat(sprintf("   📈 Demanda pico: %.2f kW\n", resultados_calibrados$summary$peak_demand))
cat(sprintf("   📉 Demanda mínima: %.2f kW\n", min(resultados_calibrados$results[[1]]$total_demand_adjusted)))
cat(sprintf("   ⚖️  Factor de carga: %.3f\n", resultados_calibrados$summary$load_factor))

cat("\n✅ VALIDACIÓN:\n")
cat(sprintf("   📏 Error Absoluto Medio: %.3f kW\n", metricas_validacion$mae))
cat(sprintf("   📐 Error Cuadrático Medio: %.3f kW\n", metricas_validacion$rmse))
cat(sprintf("   📊 Error Porcentual Medio: %.2f%%\n", metricas_validacion$mape))
cat(sprintf("   🔗 Correlación: %.3f\n", metricas_validacion$correlation))
cat(sprintf("   ⚖️  Sesgo: %.3f kW\n", metricas_validacion$bias))

# 7. GUARDAR RESULTADOS
timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")

# Guardar resultados completos
resultado_completo <- list(
  datos_reales = perfiles_eeq,
  configuracion_calibrada = config_calibrado,
  resultados_simulacion = resultados_calibrados,
  metricas_validacion = metricas_validacion,
  timestamp = timestamp,
  duracion_minutos = duracion
)

archivo_resultado <- sprintf("resultados_eeq_calibrado_%s.rds", timestamp)
saveRDS(resultado_completo, archivo_resultado)

# Guardar resumen en CSV
resumen_csv <- data.frame(
  timestamp = timestamp,
  archivos_eeq = length(unique(perfiles_eeq$file_source)),
  medidores_eeq = length(unique(perfiles_eeq$meter_id)),
  vehiculos_simulados = config_calibrado$vehicles$num_vehicles,
  dias_simulados = config_calibrado$simulation$days,
  demanda_promedio_kw = resultados_calibrados$summary$mean_daily_demand,
  demanda_pico_kw = resultados_calibrados$summary$peak_demand,
  factor_carga = resultados_calibrados$summary$load_factor,
  mae_validacion = metricas_validacion$mae,
  mape_validacion = metricas_validacion$mape,
  correlacion = metricas_validacion$correlation,
  duracion_minutos = duracion
)

archivo_resumen <- sprintf("resumen_simulacion_eeq_%s.csv", timestamp)
write.csv(resumen_csv, archivo_resumen, row.names = FALSE)

cat(sprintf("\n💾 ARCHIVOS GUARDADOS:\n"))
cat(sprintf("   📊 Resultados completos: %s\n", archivo_resultado))
cat(sprintf("   📋 Resumen CSV: %s\n", archivo_resumen))

# 8. GENERAR GRÁFICO COMPARATIVO (OPCIONAL)
if (requireNamespace("ggplot2", quietly = TRUE)) {
  cat("\n📈 Generando gráfico comparativo...\n")
  
  library(ggplot2)
  
  # Preparar datos para gráfico
  sim_data <- resultados_calibrados$results[[1]]
  n_points <- min(length(sim_data$total_demand_adjusted), nrow(perfiles_eeq), 100)
  
  df_comparacion <- data.frame(
    tiempo = 1:n_points,
    simulado = sim_data$total_demand_adjusted[1:n_points],
    real = perfiles_eeq$consumption_kwh[1:n_points]
  ) %>%
    tidyr::pivot_longer(cols = c(simulado, real), names_to = "tipo", values_to = "demanda")
  
  p <- ggplot(df_comparacion, aes(x = tiempo, y = demanda, color = tipo)) +
    geom_line(alpha = 0.8) +
    scale_color_manual(values = c("simulado" = "#1f77b4", "real" = "#ff7f0e")) +
    labs(
      title = "Comparación: Demanda Simulada vs Datos Reales EEQ",
      subtitle = sprintf("MAPE: %.2f%% | Correlación: %.3f", 
                        metricas_validacion$mape, 
                        metricas_validacion$correlation),
      x = "Tiempo (períodos)",
      y = "Demanda/Consumo (kW)",
      color = "Tipo"
    ) +
    theme_minimal() +
    theme(legend.position = "bottom")
  
  archivo_grafico <- sprintf("comparacion_eeq_%s.png", timestamp)
  ggsave(archivo_grafico, p, width = 12, height = 8, dpi = 300)
  cat(sprintf("   📊 Gráfico: %s\n", archivo_grafico))
}

cat("\n🎉 PROCESO COMPLETADO EXITOSAMENTE!\n")
cat(paste(rep("=", 60), collapse = ""), "\n")