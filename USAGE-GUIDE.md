# Azure Web App Deployment Script - Complete Usage Guide

## Overview

`deploy-clean.ps1` is a comprehensive PowerShell script for deploying Azure Web Apps at scale using Terraform. It supports fully configurable architectures from small test deployments to enterprise-scale deployments of thousands of web applications.

## Key Features

- **Scalable Architecture**: Deploy from 10 to 2000+ web applications
- **Configurable Structure**: User-defined Resource Groups, App Service Plans, and Web Apps
- **Multi-Region Support**: Deploy across multiple Azure regions
- **Parallel Deployment**: Concurrent deployment jobs for faster execution
- **Configuration Files**: JSON-based configuration management
- **Complete Lifecycle**: Deployment AND deletion capabilities
- **Safety Features**: Quota validation, error handling, and confirmation prompts

## Quick Start

### 1. Basic Deployment
```powershell
# Deploy using a configuration file (recommended)
.\deploy-clean.ps1 -ConfigFile "config-small.json"

# Deploy with custom parameters
.\deploy-clean.ps1 -TotalResourceGroups 5 -AppServicePlansPerRG 1 -WebAppsPerASP 10
```

### 2. Show Configuration
```powershell
# Preview what will be deployed
.\deploy-clean.ps1 -ConfigFile "config-small.json" -ShowConfiguration
```

### 3. Clean Up
```powershell
# Delete everything
.\deploy-clean.ps1 -ConfigFile "config-small.json" -DeleteAll
```

## Command Line Parameters

### Deployment Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `TotalResourceGroups` | int | 10 | Number of resource groups to create |
| `AppServicePlansPerRG` | int | 2 | App Service Plans per Resource Group |
| `WebAppsPerASP` | int | 10 | Web Apps per App Service Plan |
| `AppServiceSku` | string | "B1" | App Service Plan SKU (B1, B2, S1, P1v2, etc.) |
| `BaseResourceName` | string | "webapp-deploy" | Base name for all resources |
| `Regions` | string[] | @() | Target Azure regions (auto-selected if empty) |
| `MaxParallelJobs` | int | 3 | Number of parallel deployment jobs |
| `Sequential` | switch | false | Run deployments sequentially instead of parallel |

### Information Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `ShowAvailableRegions` | switch | Display all available Azure regions and exit |
| `ShowConfiguration` | switch | Show calculated deployment configuration and exit |
| `ConfigFile` | string | Load configuration from JSON file |

### Deletion Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `DeleteResources` | switch | Delete all deployed Azure resources |
| `CleanupFiles` | switch | Clean up local workspace files |
| `DeleteAll` | switch | Delete both Azure resources and local files |

## Configuration Files

The script supports JSON configuration files for repeatable deployments. Three pre-configured files are included:

### config-small.json (Testing)
```json
{
  "TotalResourceGroups": 10,
  "AppServicePlansPerRG": 2,
  "WebAppsPerASP": 20,
  "AppServiceSku": "B1",
  "BaseResourceName": "webapp-small",
  "MaxParallelJobs": 10,
  "Sequential": false,
  "Regions": ["eastus2", "centralindia"]
}
```
**Result**: 10 RGs, 20 ASPs, 400 Web Apps, 20 vCPUs

### config-medium.json (Medium Scale)
```json
{
  "TotalResourceGroups": 50,
  "AppServicePlansPerRG": 2,
  "WebAppsPerASP": 12,
  "AppServiceSku": "B1",
  "BaseResourceName": "webapp-medium",
  "MaxParallelJobs": 10,
  "Sequential": false,
  "Regions": ["eastus2", "centralindia", "westus2"]
}
```
**Result**: 50 RGs, 100 ASPs, 1200 Web Apps, 100 vCPUs

### config-2000apps.json (Enterprise Scale)
```json
{
  "TotalResourceGroups": 100,
  "AppServicePlansPerRG": 2,
  "WebAppsPerASP": 10,
  "AppServiceSku": "B1",
  "BaseResourceName": "webapp-2000",
  "MaxParallelJobs": 20,
  "Sequential": false,
  "Regions": ["eastus2", "centralindia", "westus2", "eastus", "westus"]
}
```
**Result**: 100 RGs, 200 ASPs, 2000 Web Apps, 200 vCPUs

## Detailed Usage Examples

### Example 1: Small Test Deployment
```powershell
# Preview the configuration
.\deploy-clean.ps1 -ConfigFile "config-small.json" -ShowConfiguration

# Deploy (400 web apps across 10 resource groups)
.\deploy-clean.ps1 -ConfigFile "config-small.json"

# Monitor progress (check jobs)
Get-Job

# Clean up after testing
.\deploy-clean.ps1 -ConfigFile "config-small.json" -DeleteAll
```

### Example 2: Custom Deployment
```powershell
# Custom deployment with specific parameters
.\deploy-clean.ps1 `
  -TotalResourceGroups 20 `
  -AppServicePlansPerRG 1 `
  -WebAppsPerASP 15 `
  -AppServiceSku "S1" `
  -BaseResourceName "my-webapp" `
  -Regions @("eastus2", "westus2") `
  -MaxParallelJobs 5

# Check what was deployed
az group list --query "[?starts_with(name, 'my-webapp-rg-')]" --output table
```

### Example 3: Enterprise Scale Deployment
```powershell
# Check available regions first
.\deploy-clean.ps1 -ShowAvailableRegions

# Preview enterprise configuration
.\deploy-clean.ps1 -ConfigFile "config-2000apps.json" -ShowConfiguration

# Deploy 2000 web apps
.\deploy-clean.ps1 -ConfigFile "config-2000apps.json"

# Monitor deployment progress
Get-Job | Select-Object Name, State, HasMoreData
```

### Example 4: Sequential Deployment (Safer)
```powershell
# Deploy one resource group at a time
.\deploy-clean.ps1 -ConfigFile "config-small.json" -Sequential

# Custom sequential deployment
.\deploy-clean.ps1 `
  -TotalResourceGroups 5 `
  -AppServicePlansPerRG 2 `
  -WebAppsPerASP 10 `
  -Sequential
```

## Resource Naming Convention

The script uses a consistent naming pattern:

```
Base Name: "webapp-deploy"
Resource Groups: webapp-deploy-rg-001, webapp-deploy-rg-002, ...
App Service Plans: webapp-deploy-rg-001-asp-001, webapp-deploy-rg-001-asp-002, ...
Web Apps: webapp-deploy-rg-001-asp-001-app-001, webapp-deploy-rg-001-asp-001-app-002, ...
```

## Region Selection

### Automatic Region Selection
If no regions are specified, the script automatically selects:
- `centralindia` (primary)
- `eastus2` (secondary)

### Manual Region Selection
```powershell
# Single region
-Regions @("eastus2")

# Multiple regions
-Regions @("eastus2", "westus2", "centralindia")

# Show all available regions
.\deploy-clean.ps1 -ShowAvailableRegions
```

## App Service SKU Options

| SKU | vCPUs | RAM | Use Case |
|-----|-------|-----|----------|
| B1 | 1 | 1.75 GB | Development/Testing |
| B2 | 2 | 3.5 GB | Light Production |
| B3 | 4 | 7 GB | Medium Production |
| S1 | 1 | 1.75 GB | Production (Auto-scale) |
| S2 | 2 | 3.5 GB | Production (Auto-scale) |
| S3 | 4 | 7 GB | Production (Auto-scale) |
| P1v2 | 1 | 3.5 GB | Premium Performance |
| P2v2 | 2 | 7 GB | Premium Performance |
| P3v2 | 4 | 14 GB | Premium Performance |

## Parallel vs Sequential Deployment

### Parallel Deployment (Default)
- **Faster**: Multiple resource groups deploy simultaneously
- **Resource Intensive**: Uses more CPU and memory
- **Recommended For**: Most scenarios, especially large deployments

```powershell
# Parallel with 10 jobs
.\deploy-clean.ps1 -ConfigFile "config-small.json" -MaxParallelJobs 10
```

### Sequential Deployment
- **Safer**: One resource group at a time
- **Slower**: Takes longer for large deployments
- **Recommended For**: Debugging, limited resources, or cautious deployments

```powershell
# Sequential deployment
.\deploy-clean.ps1 -ConfigFile "config-small.json" -Sequential
```

## Deletion and Cleanup

### Delete Azure Resources Only
```powershell
# Using configuration file
.\deploy-clean.ps1 -ConfigFile "config-small.json" -DeleteResources

# Using manual parameters
.\deploy-clean.ps1 -DeleteResources -BaseResourceName "webapp-small"
```

### Clean Local Files Only
```powershell
# Remove workspace directories and PowerShell jobs
.\deploy-clean.ps1 -CleanupFiles
```

### Complete Cleanup
```powershell
# Delete everything (Azure resources + local files)
.\deploy-clean.ps1 -ConfigFile "config-small.json" -DeleteAll
```

## Monitoring and Troubleshooting

### Monitor Deployment Progress
```powershell
# Check PowerShell jobs
Get-Job | Format-Table Name, State, HasMoreData

# Get job output
Receive-Job -Name "Deploy-RG-001"

# Check Azure resources
az group list --query "[?starts_with(name, 'webapp-small-rg-')]" --output table
```

### Common Issues and Solutions

#### Issue: "Quota Exceeded"
```powershell
# Check quota before deployment
.\deploy-clean.ps1 -ConfigFile "config-small.json" -ShowConfiguration
# Reduce TotalResourceGroups or change SKU
```

#### Issue: "Region Not Available"
```powershell
# Check available regions
.\deploy-clean.ps1 -ShowAvailableRegions
# Update Regions in configuration file
```

#### Issue: "Terraform State Conflicts"
```powershell
# Clean up workspace files
.\deploy-clean.ps1 -CleanupFiles
# Retry deployment
```

## Best Practices

### 1. Start Small
- Begin with `config-small.json` (400 apps) for testing
- Validate the configuration and networking
- Scale up gradually

### 2. Use Configuration Files
- Create custom JSON files for different environments
- Version control your configurations
- Document your naming conventions

### 3. Monitor Resources
- Check quota limits before large deployments
- Monitor deployment progress with `Get-Job`
- Verify resources in Azure Portal

### 4. Clean Up Regularly
- Use deletion features to clean up test deployments
- Monitor Azure costs and remove unused resources
- Clean local workspace files to save disk space

### 5. Region Strategy
- Use multiple regions for high availability
- Consider data residency requirements
- Validate region capacity before deployment

## Advanced Configuration

### Creating Custom Configuration Files
```json
{
  "TotalResourceGroups": 25,
  "AppServicePlansPerRG": 1,
  "WebAppsPerASP": 8,
  "AppServiceSku": "S1",
  "BaseResourceName": "my-custom-app",
  "MaxParallelJobs": 5,
  "Sequential": false,
  "Regions": ["eastus2", "westus2"]
}
```
**Result**: 25 RGs, 25 ASPs, 200 Web Apps

### Environment-Specific Deployments
```powershell
# Development environment
.\deploy-clean.ps1 -ConfigFile "config-dev.json"

# Staging environment
.\deploy-clean.ps1 -ConfigFile "config-staging.json"

# Production environment
.\deploy-clean.ps1 -ConfigFile "config-prod.json"
```

## Performance Optimization

### For Large Deployments (1000+ apps)
- Use more regions to distribute load
- Increase `MaxParallelJobs` (up to 20)
- Use higher SKU (B2, S1) for better performance
- Monitor Azure subscription limits

### For Resource-Constrained Environments
- Use `Sequential` mode
- Reduce `MaxParallelJobs` to 2-3
- Deploy in smaller batches

## Security Considerations

- **Resource Naming**: Use descriptive base names for easy identification
- **Region Selection**: Consider data residency and compliance requirements
- **SKU Selection**: Choose appropriate performance tiers for your workload
- **Cleanup**: Regularly delete unused resources to avoid unnecessary costs

## Support and Troubleshooting

For issues or questions:
1. Check the deployment logs in PowerShell output
2. Review Azure Activity Log for deployment failures
3. Use `Get-Job` to monitor job status
4. Refer to `DELETION-GUIDE.md` for cleanup procedures

## Version History

- **v1.0**: Initial release with fixed 2000-app deployment
- **v2.0**: Added generic configuration support
- **v3.0**: Added deletion functionality and comprehensive documentation
