# Quick Reference - deploy-clean.ps1

## Common Commands

### Deployment
```powershell
# Small test (400 apps)
.\deploy-clean.ps1 -ConfigFile "config-small.json"

# Medium scale (1200 apps)
.\deploy-clean.ps1 -ConfigFile "config-medium.json"

# Enterprise scale (2000 apps)
.\deploy-clean.ps1 -ConfigFile "config-2000apps.json"

# Custom deployment
.\deploy-clean.ps1 -TotalResourceGroups 5 -AppServicePlansPerRG 2 -WebAppsPerASP 10
```

### Information
```powershell
# Show configuration
.\deploy-clean.ps1 -ConfigFile "config-small.json" -ShowConfiguration

# Show available regions
.\deploy-clean.ps1 -ShowAvailableRegions

# Monitor jobs
Get-Job | Format-Table Name, State, HasMoreData
```

## Configuration Presets
```

### Cleanup
```powershell
# Delete everything
.\deploy-clean.ps1 -ConfigFile "config-small.json" -DeleteAll

# Delete only Azure resources
.\deploy-clean.ps1 -ConfigFile "config-small.json" -DeleteResources

# Clean only local files
.\deploy-clean.ps1 -CleanupFiles
```

## 📊 Configuration Presets

| Config File | RGs | ASPs | Apps | vCPUs | Use Case |
|------------|-----|------|------|-------|----------|
| config-small.json | 10 | 20 | 400 | 20 | Testing |
| config-medium.json | 50 | 100 | 1200 | 100 | Medium |
| config-2000apps.json | 100 | 200 | 2000 | 200 | Enterprise |

## SKU Quick Reference

| SKU | vCPUs | RAM | Best For |
|-----|-------|-----|----------|
| B1 | 1 | 1.75GB | Dev/Test |
| B2 | 2 | 3.5GB | Light Prod |
| S1 | 1 | 1.75GB | Auto-scale |
| P1v2 | 1 | 3.5GB | Premium |

## Troubleshooting

```powershell
# Check quota issues
.\deploy-clean.ps1 -ConfigFile "config-small.json" -ShowConfiguration

# Clean up failed deployments
.\deploy-clean.ps1 -CleanupFiles

# Sequential deployment (safer)
.\deploy-clean.ps1 -ConfigFile "config-small.json" -Sequential

# Check Azure resources
az group list --query "[?starts_with(name, 'webapp-small-rg-')]" --output table
```

## File Structure
```
Terraform/
├── deploy-clean.ps1          # Main deployment script
├── config-small.json         # Small deployment config
├── config-medium.json        # Medium deployment config
├── config-2000apps.json      # Large deployment config
├── USAGE-GUIDE.md            # Complete documentation
├── DELETION-GUIDE.md         # Deletion procedures
├── QUICK-REFERENCE.md        # This file
├── main.tf                   # Terraform main config
├── variables.tf              # Terraform variables
└── outputs.tf                # Terraform outputs
```
