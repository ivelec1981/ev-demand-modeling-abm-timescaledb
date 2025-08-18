# ==============================================================================
# run_validation_tests.ps1 - PowerShell Database Validation Script
# ==============================================================================
#
# This PowerShell script runs validation tests to ensure database setup
# is working correctly without requiring interactive R session.
#
# Usage: .\run_validation_tests.ps1
#
# ==============================================================================

Write-Host "🧪 EV SIMULATION DATABASE VALIDATION TESTS" -ForegroundColor Cyan
Write-Host "=" * 50

# Check if R is installed
try {
    $rVersion = & R --version 2>&1 | Select-String "R version"
    Write-Host "✅ R Found: $($rVersion.Line)" -ForegroundColor Green
} catch {
    Write-Host "❌ R not found. Please install R to run validation tests." -ForegroundColor Red
    Write-Host "Download from: https://cran.r-project.org/"
    exit 1
}

# Check if required R packages are available
Write-Host "`n📦 Checking R packages..." -ForegroundColor Yellow

$packageCheck = @"
packages <- c('DBI', 'RPostgres', 'readr', 'dplyr', 'lubridate', 'glue')
missing <- packages[!packages %in% installed.packages()[,1]]
if(length(missing) > 0) {
  cat('MISSING:', paste(missing, collapse=', '), '\n')
} else {
  cat('OK: All packages available\n')
}
"@

$packageResult = echo $packageCheck | R --slave --no-restore
if ($packageResult -match "MISSING") {
    Write-Host "❌ Missing R packages: $packageResult" -ForegroundColor Red
    Write-Host "Install with: install.packages(c('DBI', 'RPostgres', 'readr', 'dplyr', 'lubridate', 'glue'))"
    exit 1
} else {
    Write-Host "✅ All required R packages available" -ForegroundColor Green
}

# Check if PostgreSQL is running (attempt connection)
Write-Host "`n🔌 Checking database connectivity..." -ForegroundColor Yellow

$dbCheck = @"
tryCatch({
  library(DBI, quietly=TRUE)
  library(RPostgres, quietly=TRUE)
  con <- dbConnect(RPostgres::Postgres(),
    host = Sys.getenv('DB_HOST', 'localhost'),
    port = as.integer(Sys.getenv('DB_PORT', '5432')),
    dbname = Sys.getenv('DB_NAME', 'ev_simulation_db'),
    user = Sys.getenv('DB_USER', 'postgres'),
    password = Sys.getenv('DB_PASSWORD', '')
  )
  dbDisconnect(con)
  cat('OK: Database connection successful\n')
}, error = function(e) {
  cat('ERROR:', conditionMessage(e), '\n')
})
"@

$dbResult = echo $dbCheck | R --slave --no-restore
if ($dbResult -match "ERROR") {
    Write-Host "❌ Database connection failed: $dbResult" -ForegroundColor Red
    Write-Host "Please ensure:"
    Write-Host "  1. PostgreSQL is running"
    Write-Host "  2. Database 'ev_simulation_db' exists"
    Write-Host "  3. Connection credentials are correct"
    Write-Host "  4. TimescaleDB extension is installed"
} else {
    Write-Host "✅ Database connection successful" -ForegroundColor Green
}

# Check if schema exists
Write-Host "`n🏗️  Checking database schema..." -ForegroundColor Yellow

$schemaCheck = @"
tryCatch({
  library(DBI, quietly=TRUE)
  library(RPostgres, quietly=TRUE)
  con <- dbConnect(RPostgres::Postgres(),
    host = Sys.getenv('DB_HOST', 'localhost'),
    port = as.integer(Sys.getenv('DB_PORT', '5432')),
    dbname = Sys.getenv('DB_NAME', 'ev_simulation_db'),
    user = Sys.getenv('DB_USER', 'postgres'),
    password = Sys.getenv('DB_PASSWORD', '')
  )
  
  tables <- dbGetQuery(con, "
    SELECT table_name FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name IN (
      'cantones_pichincha', 'ev_models_catalog', 'ev_tariffs_quarter_hourly',
      'charging_profiles', 'ev_provincial_projections', 'bethania_weekly_monthly_profiles_v3',
      'battery_degradation_profiles', 'ev_charging_patterns_15min', 'ev_simulation_results_final'
    )
  ")
  
  dbDisconnect(con)
  cat('TABLES_FOUND:', nrow(tables), '\n')
  
}, error = function(e) {
  cat('SCHEMA_ERROR:', conditionMessage(e), '\n')
})
"@

$schemaResult = echo $schemaCheck | R --slave --no-restore
if ($schemaResult -match "TABLES_FOUND: 9") {
    Write-Host "✅ All 9 required tables found in database" -ForegroundColor Green
} elseif ($schemaResult -match "TABLES_FOUND: (\d+)") {
    $tableCount = $matches[1]
    Write-Host "⚠️  Only $tableCount/9 required tables found" -ForegroundColor Yellow
    Write-Host "Run: source('setup_complete_database.R'); setup_database()"
} else {
    Write-Host "❌ Schema check failed: $schemaResult" -ForegroundColor Red
    Write-Host "Database schema may not be created yet."
}

# Check CSV files exist
Write-Host "`n📄 Checking CSV data files..." -ForegroundColor Yellow

$csvFiles = @(
    "cantones_pichincha.csv",
    "ev_tariffs_quarter_hourly.csv", 
    "ev_models_catalog.csv",
    "charging_profiles..csv",
    "ev_provincial_projections.csv",
    "bethania_weekly_monthly_profiles_v3.csv",
    "battery_degradation_profiles.csv",
    "ev_charging_patterns_15min.csv"
)

$missingFiles = @()
$foundFiles = 0

foreach ($file in $csvFiles) {
    if (Test-Path $file) {
        Write-Host "  ✅ $file" -ForegroundColor Green
        $foundFiles++
    } else {
        Write-Host "  ❌ $file" -ForegroundColor Red
        $missingFiles += $file
    }
}

if ($missingFiles.Count -eq 0) {
    Write-Host "✅ All 8 CSV files found" -ForegroundColor Green
} else {
    Write-Host "⚠️  $($missingFiles.Count) CSV files missing" -ForegroundColor Yellow
}

# Final recommendations
Write-Host "`n" + "=" * 50
Write-Host "🎯 VALIDATION SUMMARY" -ForegroundColor Cyan
Write-Host "=" * 50

Write-Host "Next steps based on validation results:" -ForegroundColor White

if ($dbResult -match "OK" -and $schemaResult -match "TABLES_FOUND: 9" -and $foundFiles -eq 8) {
    Write-Host "✅ DATABASE READY - All components validated successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "You can now:" -ForegroundColor White
    Write-Host "  1. Run full validation: R -e \"source('validate_data_integrity.R'); generate_validation_report()\"" -ForegroundColor White
    Write-Host "  2. Execute simulation: source('src/EVSimulatorFinalDefinitive.R')" -ForegroundColor White
} elseif ($dbResult -match "ERROR") {
    Write-Host "❌ DATABASE CONNECTION ISSUES" -ForegroundColor Red
    Write-Host "  1. Start PostgreSQL service" -ForegroundColor White
    Write-Host "  2. Create database: CREATE DATABASE ev_simulation_db;" -ForegroundColor White
    Write-Host "  3. Check credentials and connection settings" -ForegroundColor White
} elseif ($schemaResult -notmatch "TABLES_FOUND: 9") {
    Write-Host "⚠️  DATABASE SCHEMA INCOMPLETE" -ForegroundColor Yellow
    Write-Host "  1. Run: R -e \"source('setup_complete_database.R'); setup_database()\"" -ForegroundColor White
    Write-Host "  2. This will create schema and load CSV data automatically" -ForegroundColor White
} else {
    Write-Host "⚠️  PARTIAL SETUP DETECTED" -ForegroundColor Yellow  
    Write-Host "  1. Complete setup: R -e \"source('setup_complete_database.R'); setup_database()\"" -ForegroundColor White
    Write-Host "  2. Validate: R -e \"source('validate_data_integrity.R'); generate_validation_report()\"" -ForegroundColor White
}

Write-Host "`n📚 For detailed help, see: setup_instructions.md" -ForegroundColor Cyan