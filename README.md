# EV Demand Modeling Framework: Agent-Based Simulation with TimescaleDB

![R](https://img.shields.io/badge/R-4.0+-blue.svg)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-12+-336791.svg)
![TimescaleDB](https://img.shields.io/badge/TimescaleDB-2.8+-orange.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)
![Status](https://img.shields.io/badge/Status-Production%20Ready-brightgreen.svg)
[![DOI](https://img.shields.io/badge/DOI-Pending-lightgrey.svg)](https://github.com/your-username/ev-demand-modeling-abm-timescaledb)

> **🚗⚡ Advanced Agent-Based Modeling framework for Electric Vehicle charging demand prediction using TimescaleDB and Big Data analytics.**

## 📖 Citation
If you use this code in your research, please cite:

```bibtex
@article{sanchez2025ev,
  title={Modelado de la demanda de energía de vehículos eléctricos: Un enfoque Big Data para la planificación energética},
  author={Sánchez-Loor, Iván and Ayala-Chauvin, Manuel},
  journal={Energies},
  year={2025},
  note={GitHub: https://github.com/your-username/ev-demand-modeling-abm-timescaledb}
}
```

## Abstract
This repository contains the complete source code and documentation for the EV demand modeling framework presented in the paper "Modelado de la demanda de energía de vehículos eléctricos". The framework combines Agent-Based Modeling (ABM) with Monte Carlo simulation and TimescaleDB architecture for quarter-hourly EV charging demand projection.

## Key Features
- **Agent-Based Modeling**: Heterogeneous EV agent behavior simulation
- **GPU Acceleration**: Optional GPU processing via GPUmatrix
- **Parallel Processing**: Multi-core CPU parallelization with future/furrr
- **TimescaleDB Integration**: High-performance time-series data management
- **Dynamic Coincidence Factor**: FC = 0.222 + 0.036*e^(-0.0003n)
- **Real Vehicle Profiles**: Integration with empirical charging data

## System Requirements
- R ≥ 4.3.0
- PostgreSQL ≥ 14 with TimescaleDB ≥ 2.8
- Minimum 16GB RAM (32GB recommended for full simulations)
- Optional: CUDA-compatible GPU for acceleration

## Quick Start
```r
# Install dependencies
source("requirements.R")

# Configure database
db_config <- list(
  dbname = "ev_simulation_db",
  host = "localhost",
  port = 5432,
  user = "your_user",
  password = "your_password"
)

# Run simulation
source("src/ev_simulator_final.R")
result <- run_final_simulation(
  processing_engine = "AUTO",
  save_to_db = TRUE
)
```

## Repository Structure
```
ev-demand-modeling-abm-timescaledb/
├── README.md                          # This documentation
├── LICENSE                            # MIT License
├── CITATION.cff                       # Citation file
├── requirements.R                     # R dependencies
├── src/                              # Source code
│   ├── ev_simulator_final.R          # Main simulator
│   ├── gpu_acceleration.R            # GPU module
│   ├── data_manager.R                # Data management
│   └── parallel_processing.R         # Parallel functions
├── database/                         # Database setup
│   ├── schema.sql                    # TimescaleDB schema
│   ├── sample_data.sql              # Sample data
│   └── setup_instructions.md        # DB setup guide
├── data/                            # Data files
│   ├── fallback_data/               # Fallback datasets
│   ├── sample_outputs/              # Example results
│   └── validation_data/             # Validation datasets
├── scripts/                         # Execution scripts
│   ├── run_simulation.R             # Main execution
│   ├── validation_tests.R           # Validation tests
│   └── performance_benchmarks.R     # Performance tests
├── docs/                           # Documentation
│   ├── technical_documentation.md   # Technical details
│   ├── api_reference.md            # API reference
│   └── troubleshooting.md          # Common issues
└── reproducibility/                 # Reproducibility
    ├── reproduction_guide.md        # Reproduction guide
    ├── environment_setup.R          # Environment setup
    └── validation_results.csv       # Validation results
```

## Installation

### 1. Clone Repository
```bash
git clone https://github.com/username/ev-demand-modeling-abm-timescaledb
cd ev-demand-modeling-abm-timescaledb
```

### 2. Install R Dependencies
```r
source("requirements.R")
```

### 3. Setup Database
```bash
# Install PostgreSQL and TimescaleDB
# Follow instructions in database/setup_instructions.md

# Create database and load schema
psql -d ev_simulation_db -f database/schema.sql
psql -d ev_simulation_db -f database/sample_data.sql
```

### 4. Configure Environment
```r
source("reproducibility/environment_setup.R")
```

## Usage

### Basic Simulation
```r
# Load the simulator
source("src/ev_simulator_final.R")

# Run with default parameters
result <- run_final_simulation(
  num_vehicles = 10000,
  simulation_days = 30,
  processing_engine = "CPU",
  save_to_db = TRUE
)

# View results
summary(result)
```

### Advanced Configuration
```r
# Custom simulation parameters
config <- list(
  vehicles = list(
    num_vehicles = 50000,
    battery_sizes = c(40, 60, 80),  # kWh
    charging_powers = c(3.7, 7.4, 11, 22)  # kW
  ),
  simulation = list(
    days = 365,
    time_resolution = 15,  # minutes
    monte_carlo_runs = 1000
  ),
  processing = list(
    engine = "GPU",  # CPU, GPU, AUTO
    parallel_cores = 8,
    memory_limit = "16GB"
  ),
  output = list(
    save_to_db = TRUE,
    export_csv = TRUE,
    generate_plots = TRUE
  )
)

result <- run_final_simulation(config)
```

### Validation and Testing
```r
# Run validation tests
source("scripts/validation_tests.R")
validation_results <- run_validation_suite()

# Performance benchmarks
source("scripts/performance_benchmarks.R")
benchmark_results <- run_performance_tests()
```

## Methodology

### Agent-Based Model
The simulation models individual EV agents with heterogeneous characteristics:
- **Battery capacity**: 40-100 kWh
- **Charging behavior**: Home, work, public charging patterns
- **Travel patterns**: Stochastic trip generation
- **Charging preferences**: Time-of-use optimization

### Monte Carlo Simulation
- **Statistical sampling**: Trip distances, charging times
- **Uncertainty quantification**: ±4.2% MAPE validation
- **Scenario analysis**: Multiple demand scenarios

### Dynamic Coincidence Factor
```
FC(n) = 0.222 + 0.036 * e^(-0.0003 * n)
```
Where n is the number of concurrent charging vehicles.

### TimescaleDB Integration
- **Time-series optimization**: Quarter-hourly data storage
- **Hypertables**: Automatic partitioning
- **Continuous aggregates**: Real-time analytics
- **Compression**: 90% storage reduction

## Results and Validation

### Model Performance
- **Accuracy**: MAPE = 4.2% ± 0.8%
- **Processing Speed**: 10,000 vehicles/hour (CPU), 100,000 vehicles/hour (GPU)
- **Scalability**: Linear scaling up to 1M vehicles
- **Memory Efficiency**: 2GB RAM for 100,000 vehicles

### Validation Datasets
- **Real charging data**: 5,000 vehicles, 6 months
- **Grid measurements**: Transformer load profiles
- **Statistical validation**: Kolmogorov-Smirnov tests

## Reproducibility

Complete reproduction instructions are available in `reproducibility/reproduction_guide.md`. The validation results (MAPE: 4.2% ± 0.8%) can be replicated using the provided test datasets.

### Environment Reproducibility
```r
# Exact package versions used
source("reproducibility/environment_setup.R")

# Validate reproduction
source("reproducibility/validate_reproduction.R")
```

## Performance Optimization

### GPU Acceleration
```r
# Enable GPU processing
Sys.setenv(GPU_ENABLED = "TRUE")
source("src/gpu_acceleration.R")

# Monitor GPU usage
monitor_gpu_performance()
```

### Parallel Processing
```r
# Configure parallel processing
library(future)
plan(multisession, workers = 8)

# Monitor performance
library(profvis)
profvis(run_final_simulation())
```

## Contributing
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/new-feature`)
3. Commit changes (`git commit -am 'Add new feature'`)
4. Push to branch (`git push origin feature/new-feature`)
5. Create Pull Request

## License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Authors
- **Iván Sánchez-Loor** - Universidad Indoamérica
- **Manuel Ayala-Chauvin** - Universidad Indoamérica

## Acknowledgments
This research was conducted as part of the SISAu Research Group at Universidad Indoamérica, Quito, Ecuador.

## Contact
- Email: ivan.sanchez@uti.edu.ec
- Research Group: SISAu - Universidad Indoamérica
- Location: Quito, Ecuador

---

**Keywords**: Electric Vehicles, Agent-Based Modeling, TimescaleDB, Big Data, Energy Planning, Monte Carlo Simulation, GPU Computing