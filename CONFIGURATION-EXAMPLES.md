# Example Configuration Files

This document provides examples of configuration files for different deployment scenarios.

## Development Environment (config-dev.json)
```json
{
  "TotalResourceGroups": 3,
  "AppServicePlansPerRG": 1,
  "WebAppsPerASP": 5,
  "AppServiceSku": "B1",
  "BaseResourceName": "dev-webapp",
  "MaxParallelJobs": 3,
  "Sequential": false,
  "Regions": ["eastus2"]
}
```
**Result**: 3 RGs, 3 ASPs, 15 Web Apps, 3 vCPUs  
**Use Case**: Developer testing, feature validation

## Staging Environment (config-staging.json)
```json
{
  "TotalResourceGroups": 10,
  "AppServicePlansPerRG": 2,
  "WebAppsPerASP": 8,
  "AppServiceSku": "B2",
  "BaseResourceName": "staging-webapp",
  "MaxParallelJobs": 5,
  "Sequential": false,
  "Regions": ["eastus2", "westus2"]
}
```
**Result**: 10 RGs, 20 ASPs, 160 Web Apps, 40 vCPUs  
**Use Case**: Pre-production testing, performance validation

## Production Environment (config-prod.json)
```json
{
  "TotalResourceGroups": 50,
  "AppServicePlansPerRG": 3,
  "WebAppsPerASP": 8,
  "AppServiceSku": "S1",
  "BaseResourceName": "prod-webapp",
  "MaxParallelJobs": 10,
  "Sequential": false,
  "Regions": ["eastus2", "westus2", "centralindia", "westeurope"]
}
```
**Result**: 50 RGs, 150 ASPs, 1200 Web Apps, 150 vCPUs  
**Use Case**: Production workloads with auto-scaling

## High Performance (config-highperf.json)
```json
{
  "TotalResourceGroups": 25,
  "AppServicePlansPerRG": 2,
  "WebAppsPerASP": 5,
  "AppServiceSku": "P1v2",
  "BaseResourceName": "highperf-webapp",
  "MaxParallelJobs": 8,
  "Sequential": false,
  "Regions": ["eastus2", "westus2"]
}
```
**Result**: 25 RGs, 50 ASPs, 250 Web Apps, 50 vCPUs  
**Use Case**: High-performance applications, premium features

## Multi-Region Disaster Recovery (config-dr.json)
```json
{
  "TotalResourceGroups": 40,
  "AppServicePlansPerRG": 2,
  "WebAppsPerASP": 10,
  "AppServiceSku": "S2",
  "BaseResourceName": "dr-webapp",
  "MaxParallelJobs": 8,
  "Sequential": false,
  "Regions": ["eastus2", "westus2", "centralindia", "westeurope", "southeastasia"]
}
```
**Result**: 40 RGs, 80 ASPs, 800 Web Apps, 160 vCPUs  
**Use Case**: Disaster recovery, global distribution

## Cost-Optimized (config-cost.json)
```json
{
  "TotalResourceGroups": 20,
  "AppServicePlansPerRG": 1,
  "WebAppsPerASP": 15,
  "AppServiceSku": "B1",
  "BaseResourceName": "cost-webapp",
  "MaxParallelJobs": 5,
  "Sequential": true,
  "Regions": ["centralindia"]
}
```
**Result**: 20 RGs, 20 ASPs, 300 Web Apps, 20 vCPUs  
**Use Case**: Budget-conscious deployments, cost optimization

## Load Testing (config-loadtest.json)
```json
{
  "TotalResourceGroups": 100,
  "AppServicePlansPerRG": 1,
  "WebAppsPerASP": 20,
  "AppServiceSku": "B1",
  "BaseResourceName": "loadtest-webapp",
  "MaxParallelJobs": 20,
  "Sequential": false,
  "Regions": ["eastus2", "westus2", "centralindia"]
}
```
**Result**: 100 RGs, 100 ASPs, 2000 Web Apps, 100 vCPUs  
**Use Case**: Load testing, stress testing, capacity planning

## Quick Prototype (config-prototype.json)
```json
{
  "TotalResourceGroups": 1,
  "AppServicePlansPerRG": 1,
  "WebAppsPerASP": 3,
  "AppServiceSku": "B1",
  "BaseResourceName": "prototype-webapp",
  "MaxParallelJobs": 1,
  "Sequential": true,
  "Regions": ["eastus2"]
}
```
**Result**: 1 RG, 1 ASP, 3 Web Apps, 1 vCPU  
**Use Case**: Quick prototyping, proof of concept

## Usage Examples

### Create and Use Custom Configuration
```powershell
# Create your custom configuration file
# (Copy one of the examples above and modify as needed)

# Test the configuration
.\deploy-clean.ps1 -ConfigFile "config-dev.json" -ShowConfiguration

# Deploy using the configuration
.\deploy-clean.ps1 -ConfigFile "config-dev.json"

# Clean up when done
.\deploy-clean.ps1 -ConfigFile "config-dev.json" -DeleteAll
```

### Environment-Specific Deployments
```powershell
# Deploy to development
.\deploy-clean.ps1 -ConfigFile "config-dev.json"

# Deploy to staging  
.\deploy-clean.ps1 -ConfigFile "config-staging.json"

# Deploy to production
.\deploy-clean.ps1 -ConfigFile "config-prod.json"
```

## Configuration Guidelines

### Resource Group Count
- **1-5 RGs**: Quick testing, prototypes
- **10-25 RGs**: Development/staging environments
- **50-100 RGs**: Production environments
- **100+ RGs**: Enterprise scale, load testing

### App Service Plan SKU Selection
- **B1/B2**: Development, testing, cost-sensitive
- **S1/S2/S3**: Production with auto-scaling
- **P1v2/P2v2/P3v2**: High performance, premium features

### Region Strategy
- **Single Region**: Development, cost optimization
- **Two Regions**: Basic redundancy
- **3+ Regions**: High availability, disaster recovery

### Parallel Jobs
- **1-3 Jobs**: Resource-constrained environments
- **5-10 Jobs**: Standard deployments
- **15-20 Jobs**: Large-scale, fast deployments

### Sequential vs Parallel
- **Sequential**: Debugging, cautious deployments
- **Parallel**: Standard operation, faster deployments
