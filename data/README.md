# Data Directory Structure

This directory contains all datasets used in the EV demand modeling framework, including real consumption profiles from EEQ (Empresa Eléctrica Quito) and synthetic validation datasets.

## Directory Structure

```
data/
├── raw/                           # Raw, unprocessed data
│   ├── eeq_profiles/             # Real consumption profiles from EEQ
│   │   ├── residential/          # Residential customer profiles
│   │   ├── commercial/           # Commercial customer profiles
│   │   └── industrial/           # Industrial customer profiles
│   └── grid_infrastructure/      # Grid infrastructure data
├── processed/                     # Cleaned and processed datasets
│   ├── consumption_profiles.csv  # Standardized consumption profiles
│   ├── charging_patterns.csv     # Extracted charging patterns
│   └── validation_datasets.csv   # Processed validation data
├── sample_outputs/               # Example simulation results
│   ├── small_simulation/         # Results from 1,000 vehicle simulation
│   ├── medium_simulation/        # Results from 10,000 vehicle simulation
│   └── large_simulation/         # Results from 50,000+ vehicle simulation
├── validation_data/              # Data for model validation
│   ├── measured_demand/          # Real measured demand profiles
│   ├── charging_station_logs/    # Actual EV charging station data
│   └── grid_measurements/        # Grid transformer measurements
└── fallback_data/               # Synthetic fallback data when real data unavailable
    ├── synthetic_profiles.csv    # Generated consumption profiles
    └── default_parameters.json   # Default simulation parameters
```

## Data Sources

### 1. EEQ (Empresa Eléctrica Quito) Data
- **Source**: Real customer consumption profiles from EEQ distribution network
- **Period**: 2023-2025 (various time periods)
- **Resolution**: 15-minute intervals (quarter-hourly)
- **Format**: CSV files with timestamp and consumption data
- **Location**: `raw/eeq_profiles/`

### 2. Grid Infrastructure Data
- **Source**: EEQ transformer and distribution network data
- **Content**: Transformer locations, capacities, and baseline load factors
- **Format**: CSV and JSON files
- **Location**: `raw/grid_infrastructure/`

### 3. Validation Datasets
- **Source**: Independent measurements and academic datasets
- **Purpose**: Model validation and benchmarking
- **Location**: `validation_data/`

## Data Processing Pipeline

1. **Raw Data Ingestion** (`raw/`) → **Data Cleaning** → **Processed Data** (`processed/`)
2. **Feature Extraction** → **Pattern Analysis** → **Model Calibration**
3. **Validation** → **Results** (`sample_outputs/`)

## File Naming Conventions

### EEQ Profile Files
- `monthly_load_profile-{meter_id}-{YYYYMMDD}.csv`
- `PerfilCarga_{customer_id}_{meter_id}_{YYYYMMDD}.csv`

### Processed Files
- `consumption_profiles_{processing_date}.csv`
- `charging_patterns_{analysis_date}.csv`
- `validation_results_{simulation_id}.csv`

## Data Quality Standards

All data files should include:
- **Header row** with column names
- **Timestamp** in ISO 8601 format or clearly documented format
- **Units** specified in column headers or documentation
- **Missing values** handled consistently (NA or NULL)
- **Metadata** file (.md) describing content and processing steps

## Usage Examples

### Loading EEQ Data
```r
# Load raw EEQ profiles
source("src/real_data_loader.R")
eeq_data <- load_eeq_consumption_profiles("data/raw/eeq_profiles/")

# Load processed consumption profiles
consumption_data <- read.csv("data/processed/consumption_profiles.csv")
```

### Using Sample Outputs
```r
# Load example simulation results
sample_results <- readRDS("data/sample_outputs/medium_simulation/results.rds")

# Compare with validation data
validation_data <- read.csv("data/validation_data/measured_demand.csv")
```

## Data Privacy and Ethics

- All customer identifiers have been anonymized or pseudonymized
- Data usage complies with EEQ data sharing agreements
- Personal information has been removed or encrypted
- Aggregated data only - no individual customer behavior tracking

## Data Maintenance

- **Update Frequency**: Monthly for recent data, annually for historical data
- **Quality Checks**: Automated validation scripts run before each simulation
- **Backup**: All raw data backed up in multiple locations
- **Version Control**: Data changes tracked with timestamps and descriptions

## Contributing New Data

When adding new datasets:

1. Place raw data in appropriate `raw/` subdirectory
2. Create metadata file describing source, format, and content
3. Run data quality checks using `scripts/validate_data.R`
4. Process data using standardized pipeline
5. Update this README with new data description

## Data Size and Storage

- **Raw EEQ Data**: ~2GB (764 files, 21,600 records)
- **Processed Data**: ~500MB (optimized formats)
- **Sample Outputs**: ~100MB per large simulation
- **Total Project Data**: ~5GB (estimated)

## References

- EEQ (Empresa Eléctrica Quito): https://www.eeq.com.ec/
- Ecuador National Energy Plan 2021-2030
- IEEE Standards for Power System Analysis
- IEC 61850 for Smart Grid Communications

---

For questions about data access or processing, contact the research team or create an issue in the repository.