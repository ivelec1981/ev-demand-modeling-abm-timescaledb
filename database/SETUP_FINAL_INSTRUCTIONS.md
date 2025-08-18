# Instrucciones Finales para Completar el Setup

## 🎯 Estado Actual
- ✅ PostgreSQL funcionando (puerto 5432 activo)
- ✅ Todos los CSV de datos en su lugar
- ✅ Scripts de setup preparados al 100%
- ✅ Sistema de validación completo

## 📋 Pasos Finales (10-15 minutos)

### Paso 1: Verificar/Instalar R (si es necesario)

#### Opción A: Si ya tienes R instalado
Abre **RStudio** o **R Console** y ve directamente al Paso 2.

#### Opción B: Si necesitas instalar R
1. Descarga R desde: https://cran.r-project.org/bin/windows/base/
2. Instala R siguiendo el asistente
3. Opcionalmente instala RStudio: https://www.rstudio.com/products/rstudio/download/

### Paso 2: Instalar paquetes R requeridos

En la consola de R ejecuta:
```r
# Instalar paquetes necesarios
install.packages(c("DBI", "RPostgres", "readr", "dplyr", "lubridate", "glue"))
```

### Paso 3: Configurar conexión a la base de datos

#### Opción A: Usar variables de ambiente (recomendado)
```r
# En R, establecer variables de conexión
Sys.setenv(
  DB_HOST = "localhost",
  DB_PORT = "5432",
  DB_NAME = "ev_simulation_db",
  DB_USER = "postgres",
  DB_PASSWORD = "tu_password_aqui"  # Cambia por tu password real
)
```

#### Opción B: Modificar directamente los scripts
Edita el archivo `load_csv_data.R` líneas 23-29 con tus credenciales.

### Paso 4: Crear la base de datos (si no existe)

#### Usando pgAdmin (GUI):
1. Abre pgAdmin
2. Conecta a tu servidor PostgreSQL
3. Click derecho en "Databases" → "Create" → "Database..."
4. Nombre: `ev_simulation_db`
5. Click "Save"

#### Usando línea de comandos (si tienes psql en PATH):
```sql
CREATE DATABASE ev_simulation_db;
```

### Paso 5: Ejecutar el setup completo

En R, navega al directorio del proyecto y ejecuta:
```r
# Cambiar al directorio correcto
setwd("C:/Users/LEGION/Maestria BigData/Trabajo Titulacion/ev-demand-modeling-abm-timescaledb/database")

# Ejecutar setup completo
source("setup_complete_database.R")
setup_database()
```

### Paso 6: Verificar que todo funciona

```r
# Verificar estado de la base de datos
check_database_status()

# Ejecutar validación completa
source("validate_data_integrity.R")
generate_validation_report()
```

## 🎉 Resultado Esperado

Si todo funciona correctamente, deberías ver:

```
🎉 DATABASE SETUP COMPLETE!
✅ Schema created with all tables and indexes
✅ CSV data loaded successfully  
✅ TimescaleDB features configured
✅ Database ready for EV simulation
```

Y en la validación:
```
🎉 OVERALL ASSESSMENT: DATABASE READY FOR SIMULATION
All critical validations passed. The database is properly configured.
```

## 🚀 Probar la Simulación

Una vez que la base de datos esté lista:

```r
# Cargar tu código de simulación
source("../ev-demand-modeling-abm-timescaledb.txt")

# O el archivo específico de simulación
source("../src/EVSimulatorFinalDefinitive.R")

# Ejecutar una simulación de prueba
simulator <- EVSimulatorFinalDefinitive$new()
results <- simulator$run_simulation(
  target_year = 2025,
  n_vehicles_base = 100,  # Empezar con pocos para prueba
  projection_type = "Base"
)
```

## 🆘 Si Encuentras Problemas

### Error de conexión a la base de datos:
- Verifica que PostgreSQL esté corriendo
- Confirma credenciales (usuario/password)
- Asegúrate de que la base de datos `ev_simulation_db` existe

### Error de paquetes R:
```r
install.packages(c("DBI", "RPostgres", "readr", "dplyr", "lubridate", "glue"))
```

### Error de TimescaleDB:
- Instala TimescaleDB extension si no está disponible
- O usa el esquema simple: `source("schema_original_aligned.sql")`

### Error con archivos CSV:
- Verifica que todos los archivos CSV estén en la carpeta `database/`
- Confirma que no hay caracteres especiales en las rutas

## 📞 Contacto

Si necesitas ayuda adicional:
1. Revisa los archivos de log de error
2. Ejecuta validaciones individuales para identificar el problema específico
3. Consulta `TESTING_VERIFICATION_SUMMARY.md` para troubleshooting detallado

---

**Una vez completados estos pasos, tu proyecto estará 100% funcional y listo para ejecutar simulaciones de demanda de vehículos eléctricos.**