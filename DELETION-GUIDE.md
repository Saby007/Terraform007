# Azure Web App Deployment - Deletion Guide

This guide explains how to use the deletion features in the `deploy-clean.ps1` script.

## Deletion Options

The script provides three deletion switches:

### 1. Delete Azure Resources Only
```powershell
# Delete resources using configuration file
.\deploy-clean.ps1 -ConfigFile "config-small.json" -DeleteResources

# Delete resources using parameters
.\deploy-clean.ps1 -DeleteResources -BaseResourceName "webapp-small"
```

### 2. Clean Up Local Files Only
```powershell
# Clean up workspace directories and PowerShell jobs
.\deploy-clean.ps1 -CleanupFiles
```

### 3. Delete Everything (Resources + Files)
```powershell
# Complete cleanup using configuration file
.\deploy-clean.ps1 -ConfigFile "config-small.json" -DeleteAll

# Complete cleanup using parameters
.\deploy-clean.ps1 -DeleteAll -BaseResourceName "webapp-small"
```

## What Gets Deleted

### Azure Resources (`-DeleteResources`)
- All resource groups matching the naming pattern: `{BaseResourceName}-rg-001`, `{BaseResourceName}-rg-002`, etc.
- All resources within those resource groups (App Service Plans, Web Apps, etc.)
- Deletion runs asynchronously for faster processing

### Local Files (`-CleanupFiles`)
- All workspace directories: `deploy-workspace-rg-*`
- All PowerShell background jobs
- Terraform state files and temporary files

## Safety Features

1. **Confirmation Required**: Script asks for confirmation before deleting Azure resources
2. **Non-Destructive Discovery**: Script first lists what will be deleted
3. **Asynchronous Deletion**: Azure deletions run in background for better performance
4. **Error Handling**: Continues deletion even if some resources fail

## Example Usage Scenarios

### Scenario 1: Clean up after testing small deployment
```powershell
.\deploy-clean.ps1 -ConfigFile "config-small.json" -DeleteAll
```

### Scenario 2: Remove only Azure resources, keep local files
```powershell
.\deploy-clean.ps1 -ConfigFile "config-2000apps.json" -DeleteResources
```

### Scenario 3: Clean up workspace after deployment issues
```powershell
.\deploy-clean.ps1 -CleanupFiles
```

### Scenario 4: Manual cleanup with specific base name
```powershell
.\deploy-clean.ps1 -DeleteResources -BaseResourceName "my-custom-webapp"
```

## Monitoring Deletion Progress

After initiating resource deletion, monitor progress with:
```powershell
# Check remaining resource groups
az group list --query "[?starts_with(name, 'your-base-name-rg-')]" --output table

# Check specific resource group
az group show --name "your-base-name-rg-001" --output table
```

## Configuration File Support

The deletion process respects the same configuration files used for deployment:
- `config-small.json` - 10 RGs, 400 web apps
- `config-medium.json` - 50 RGs, 1200 web apps  
- `config-2000apps.json` - 100 RGs, 2000 web apps

## Error Scenarios

### No Resources Found
```
[INFO] No resource groups found with base name: webapp-test
```
This means either:
- Resources were already deleted
- Different base name was used during deployment
- Resources haven't been deployed yet

### Partial Deletion Failures
The script continues deleting other resources even if some fail. Check the deletion summary for details.

## Best Practices

1. **Test with small deployments first** using `config-small.json`
2. **Use configuration files** instead of manual parameters for consistency
3. **Clean up local files** after successful deletions to save disk space
4. **Monitor Azure billing** to ensure all resources are properly deleted
5. **Keep configuration files** for reproducible deployments and deletions
