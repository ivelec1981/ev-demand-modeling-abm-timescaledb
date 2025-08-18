# Contributing to EV Demand Modeling Framework

🎉 Thank you for your interest in contributing to the EV Demand Modeling Framework! 

## Table of Contents
- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [How to Contribute](#how-to-contribute)
- [Development Setup](#development-setup)
- [Coding Standards](#coding-standards)
- [Testing Guidelines](#testing-guidelines)
- [Submitting Changes](#submitting-changes)

## Code of Conduct

This project adheres to academic and professional standards. By participating, you agree to:
- Be respectful and inclusive in all interactions
- Focus on constructive feedback and collaboration
- Respect intellectual property and proper attribution
- Follow academic integrity principles

## Getting Started

### Prerequisites
- R 4.0+ with required packages
- PostgreSQL 12+ with TimescaleDB
- Git knowledge
- Basic understanding of Agent-Based Modeling

### Quick Development Setup
```bash
git clone https://github.com/your-username/ev-demand-modeling-abm-timescaledb
cd ev-demand-modeling-abm-timescaledb

# Setup database
source("database/setup_complete_database.R")
setup_database()

# Run tests
source("database/test_database_setup.R")
run_complete_test_suite()
```

## How to Contribute

### 🐛 Bug Reports
Use GitHub Issues with the `bug` label and include:
- Clear description of the problem
- Steps to reproduce
- Expected vs actual behavior
- System information (R version, OS, database version)
- Error messages or logs

### 💡 Feature Requests
Use GitHub Issues with the `enhancement` label and include:
- Clear use case description
- Proposed solution or approach
- Potential impact on performance
- Academic or practical justification

### 📖 Documentation Improvements
- Fix typos or unclear explanations
- Add examples or use cases
- Improve setup instructions
- Translate documentation (Spanish/English)

### 🧪 Research Contributions
- New modeling approaches
- Performance optimizations
- Validation with new datasets
- Integration with other tools

## Development Setup

### Environment Configuration
```r
# Install development dependencies
install.packages(c(
  "DBI", "RPostgres", "readr", "dplyr", "lubridate",
  "testthat", "devtools", "roxygen2", "profvis"
))

# Setup environment
source("reproducibility/environment_setup.R")
```

### Database Development
```sql
-- Create development database
CREATE DATABASE ev_simulation_dev_db;

-- Load schema
\i database/complete_schema_with_source_tables.sql
```

## Coding Standards

### R Code Style
Follow the [tidyverse style guide](https://style.tidyverse.org/):

```r
# Good
calculate_charging_demand <- function(vehicles, time_period) {
  result <- vehicles %>%
    filter(charging_status == "active") %>%
    group_by(time_period) %>%
    summarise(total_demand = sum(power_kw), .groups = "drop")
  
  return(result)
}

# Bad
calcChargingDemand<-function(v,t){
result<-aggregate(v$power_kw,by=list(t),FUN=sum)
return(result)
}
```

### SQL Standards
- Use lowercase with underscores for table/column names
- Include comments for complex queries
- Use proper indentation
- Optimize for TimescaleDB performance

### Documentation Standards
- Use roxygen2 for R function documentation
- Include examples in documentation
- Keep README files updated
- Document algorithm changes with academic references

## Testing Guidelines

### Required Tests
All contributions must include:

1. **Unit Tests**
```r
test_that("charging demand calculation works correctly", {
  test_vehicles <- data.frame(
    vehicle_id = 1:3,
    power_kw = c(7.4, 11.0, 3.7),
    charging_status = "active"
  )
  
  result <- calculate_charging_demand(test_vehicles, "2025-01-01 12:00")
  expect_equal(sum(result$total_demand), 22.1)
})
```

2. **Integration Tests**
```r
# Test database integration
test_that("data loading works with real CSV files", {
  con <- connect_test_database()
  result <- load_csv_data(con)
  expect_true(result$success)
  dbDisconnect(con)
})
```

3. **Performance Tests**
```r
# Test performance requirements
test_that("simulation meets performance requirements", {
  start_time <- Sys.time()
  result <- run_simulation(num_vehicles = 1000)
  duration <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
  
  expect_lt(duration, 60)  # Should complete within 60 seconds
})
```

### Running Tests
```r
# Run all tests
source("database/test_database_setup.R")
run_complete_test_suite()

# Run specific test file
testthat::test_file("tests/test_simulation_core.R")

# Check test coverage
covr::report()
```

## Submitting Changes

### Pull Request Process

1. **Fork and Clone**
```bash
git clone https://github.com/your-username/ev-demand-modeling-abm-timescaledb
cd ev-demand-modeling-abm-timescaledb
git remote add upstream https://github.com/original-repo/ev-demand-modeling-abm-timescaledb
```

2. **Create Feature Branch**
```bash
git checkout -b feature/your-feature-name
# or
git checkout -b bugfix/issue-number
```

3. **Make Changes**
- Follow coding standards
- Add tests for new functionality
- Update documentation
- Run validation tests

4. **Commit Changes**
```bash
git add .
git commit -m "feat: add new charging pattern analysis

- Implement dynamic charging pattern detection
- Add validation against real EEQ data  
- Update documentation with new examples
- Fixes #123"
```

5. **Push and Create PR**
```bash
git push origin feature/your-feature-name
```
Then create a Pull Request on GitHub.

### Commit Message Format
Use conventional commits:
- `feat:` - New feature
- `fix:` - Bug fix
- `docs:` - Documentation changes
- `test:` - Test additions/changes
- `refactor:` - Code refactoring
- `perf:` - Performance improvements
- `chore:` - Maintenance tasks

### PR Requirements
- [ ] All tests pass
- [ ] Documentation updated
- [ ] Performance impact assessed
- [ ] Academic integrity maintained
- [ ] Code review completed

## Performance Considerations

### Memory Usage
- Profile memory usage for large simulations
- Use data.table for large datasets
- Implement chunked processing where appropriate

### Database Performance
- Index new columns appropriately
- Test query performance with large datasets
- Consider TimescaleDB-specific optimizations

### Parallel Processing
- Ensure thread-safety for parallel code
- Test with different core counts
- Monitor resource usage

## Academic Integrity

### Citation Requirements
- Properly cite any external algorithms or methods
- Include references in code comments where appropriate
- Update bibliography for new academic sources

### Data Attribution
- Ensure proper attribution for any external datasets
- Respect data privacy and licensing requirements
- Document data sources and preprocessing steps

## Getting Help

### Community Support
- **GitHub Discussions**: General questions and ideas
- **GitHub Issues**: Bug reports and feature requests
- **Email**: Direct contact with maintainers for academic collaboration

### Development Resources
- [R Documentation](https://www.r-project.org/other-docs.html)
- [TimescaleDB Documentation](https://docs.timescale.com/)
- [Agent-Based Modeling Resources](https://www.agent-based-models.com/)

## Recognition

Contributors will be acknowledged in:
- CONTRIBUTORS.md file
- Academic publications (where appropriate)
- Release notes for significant contributions
- Special recognition for major feature contributions

Thank you for contributing to advancing EV demand modeling research! 🚗⚡