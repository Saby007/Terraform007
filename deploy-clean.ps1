# Generic deployment script for Azure Web Apps at scale
# Fully configurable architecture with user-defined parameters
# Architecture: User-defined RGs, ASPs per RG, Web Apps per ASP

param(
    [int]$MaxParallelJobs = 3,                    # Number of parallel jobs (1 job = 1 RG)
    [switch]$Sequential = $false,                 # Run deployments sequentially
    [string[]]$Regions = @(),                     # Target Azure regions  
    [int]$TotalResourceGroups = 10,               # Total number of resource groups to deploy
    [int]$AppServicePlansPerRG = 2,               # Number of App Service Plans per Resource Group
    [int]$WebAppsPerASP = 10,                     # Number of Web Apps per App Service Plan
    [string]$AppServiceSku = "B1",                # App Service Plan SKU (B1, B2, S1, etc.)
    [string]$BaseResourceName = "webapp-deploy", # Base name for all resources
    [switch]$ShowAvailableRegions = $false,      # Show available regions and exit
    [switch]$ShowConfiguration = $false,         # Show calculated configuration and exit
    [string]$ConfigFile = "",                    # Optional: Load configuration from JSON file
    [switch]$DeleteResources = $false,           # Delete all deployed Azure resources
    [switch]$CleanupFiles = $false,              # Clean up local workspace files
    [switch]$DeleteAll = $false                  # Delete everything (resources + files)
)

# Load configuration from file if specified
if ($ConfigFile -and (Test-Path $ConfigFile)) {
    Write-Host "Loading configuration from: $ConfigFile" -ForegroundColor Cyan
    $config = Get-Content $ConfigFile | ConvertFrom-Json
    
    # Override parameters with config file values
    if ($config.TotalResourceGroups) { $TotalResourceGroups = $config.TotalResourceGroups }
    if ($config.AppServicePlansPerRG) { $AppServicePlansPerRG = $config.AppServicePlansPerRG }
    if ($config.WebAppsPerASP) { $WebAppsPerASP = $config.WebAppsPerASP }
    if ($config.AppServiceSku) { $AppServiceSku = $config.AppServiceSku }
    if ($config.BaseResourceName) { $BaseResourceName = $config.BaseResourceName }
    if ($config.MaxParallelJobs) { $MaxParallelJobs = $config.MaxParallelJobs }
    if ($config.Regions) { $Regions = $config.Regions }
    if ($config.Sequential) { $Sequential = $config.Sequential }
}

# SKU to vCPU mapping
$skuToVCpuMapping = @{
    "F1" = 0    # Free tier - shared
    "D1" = 0    # Shared tier - shared  
    "B1" = 1    # Basic
    "B2" = 2    # Basic
    "B3" = 4    # Basic
    "S1" = 1    # Standard
    "S2" = 2    # Standard
    "S3" = 4    # Standard
    "P1V2" = 1  # Premium V2
    "P2V2" = 2  # Premium V2
    "P3V2" = 4  # Premium V2
    "P1V3" = 2  # Premium V3
    "P2V3" = 4  # Premium V3
    "P3V3" = 8  # Premium V3
}

# Available regions with their typical vCPU quotas
$availableRegions = @{
    "centralindia" = @{ Name = "Central India"; Description = "Asia Pacific region" }
    "eastus2" = @{ Name = "East US 2"; Description = "North America region" }
    "eastus" = @{ Name = "East US"; Description = "North America region" }
    "westus2" = @{ Name = "West US 2"; Description = "North America region" }
    "westus3" = @{ Name = "West US 3"; Description = "North America region" }
    "centralus" = @{ Name = "Central US"; Description = "North America region" }
    "northeurope" = @{ Name = "North Europe"; Description = "Europe region" }
    "westeurope" = @{ Name = "West Europe"; Description = "Europe region" }
    "southeastasia" = @{ Name = "Southeast Asia"; Description = "Asia Pacific region" }
    "japaneast" = @{ Name = "Japan East"; Description = "Asia Pacific region" }
    "australiaeast" = @{ Name = "Australia East"; Description = "Asia Pacific region" }
    "uksouth" = @{ Name = "UK South"; Description = "Europe region" }
    "canadacentral" = @{ Name = "Canada Central"; Description = "North America region" }
    "brazilsouth" = @{ Name = "Brazil South"; Description = "South America region" }
}

# Show available regions if requested
if ($ShowAvailableRegions) {
    Write-Host "`n========== AVAILABLE REGIONS ==========" -ForegroundColor Cyan
    Write-Host "Region Code        | Display Name         | Description" -ForegroundColor Yellow
    Write-Host "-------------------|---------------------|----------------------------------" -ForegroundColor Yellow
    foreach ($region in $availableRegions.GetEnumerator() | Sort-Object Key) {
        $code = $region.Key.PadRight(18)
        $name = $region.Value.Name.PadRight(19)
        $desc = $region.Value.Description
        Write-Host "$code | $name | $desc" -ForegroundColor White
    }
    Write-Host "`nUsage Examples:" -ForegroundColor Green
    Write-Host "  .\deploy-clean.ps1 -Regions @('centralindia', 'eastus2') -TotalResourceGroups 50" -ForegroundColor Green
    Write-Host "  .\deploy-clean.ps1 -ConfigFile 'myconfig.json'" -ForegroundColor Green
    return
}

# Validate App Service SKU
if (-not $skuToVCpuMapping.ContainsKey($AppServiceSku)) {
    Write-Host "ERROR: Invalid App Service SKU '$AppServiceSku'. Valid options: $($skuToVCpuMapping.Keys -join ', ')" -ForegroundColor Red
    return
}

# Configuration - Use user-specified regions or defaults
if ($Regions.Count -eq 0) {
    $regions = @("centralindia", "eastus2")  # Default regions
    Write-Host "Using default regions: $($regions -join ', ')" -ForegroundColor Yellow
} else {
    $regions = $Regions
    # Validate user-specified regions
    foreach ($region in $regions) {
        if (-not $availableRegions.ContainsKey($region)) {
            Write-Host "ERROR: Invalid region '$region'. Use -ShowAvailableRegions to see valid options." -ForegroundColor Red
            return
        }
    }
}

# Calculate derived values
$totalAppServicePlans = $TotalResourceGroups * $AppServicePlansPerRG
$totalWebApps = $TotalResourceGroups * $AppServicePlansPerRG * $WebAppsPerASP
$vCpusPerASP = $skuToVCpuMapping[$AppServiceSku]
$totalVCpusRequired = $totalAppServicePlans * $vCpusPerASP

# Show configuration if requested
if ($ShowConfiguration) {
    Write-Host "`n========== DEPLOYMENT CONFIGURATION ==========" -ForegroundColor Cyan
    Write-Host "Base Resource Name:       $BaseResourceName" -ForegroundColor White
    Write-Host "Target Regions:           $($regions -join ', ')" -ForegroundColor White
    Write-Host "Resource Groups:          $TotalResourceGroups" -ForegroundColor White
    Write-Host "App Service Plans per RG: $AppServicePlansPerRG" -ForegroundColor White
    Write-Host "Web Apps per ASP:         $WebAppsPerASP" -ForegroundColor White
    Write-Host "App Service SKU:          $AppServiceSku ($vCpusPerASP vCPU each)" -ForegroundColor White
    Write-Host "Max Parallel Jobs:        $MaxParallelJobs" -ForegroundColor White
    Write-Host "Sequential Mode:          $Sequential" -ForegroundColor White
    Write-Host "`n========== CALCULATED TOTALS ==========" -ForegroundColor Cyan
    Write-Host "Total App Service Plans:  $totalAppServicePlans" -ForegroundColor Yellow
    Write-Host "Total Web Apps:           $totalWebApps" -ForegroundColor Yellow
    Write-Host "Total vCPUs Required:     $totalVCpusRequired" -ForegroundColor Yellow
    Write-Host "`nDistribution per Region:" -ForegroundColor Green
    $rgsPerRegion = [math]::Ceiling($TotalResourceGroups / $regions.Count)
    foreach ($region in $regions) {
        $regionRGs = [math]::Min($rgsPerRegion, $TotalResourceGroups - ($regions.IndexOf($region) * $rgsPerRegion))
        if ($regionRGs -gt 0) {
            $regionWebApps = $regionRGs * $AppServicePlansPerRG * $WebAppsPerASP
            $regionVCpus = $regionRGs * $AppServicePlansPerRG * $vCpusPerASP
            Write-Host "  $($availableRegions[$region].Name): $regionRGs RGs, $regionWebApps Web Apps, $regionVCpus vCPUs" -ForegroundColor White
        }
    }
    return
}

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "SUCCESS" { "Green" }
        "ERROR" { "Red" }
        "WARNING" { "Yellow" }
        default { "White" }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Deploy-ResourceGroup {
    param([int]$RgNumber, [string[]]$RegionsList, [hashtable]$Config)
    
    $workspaceDir = "deploy-workspace-rg-{0:D3}" -f $RgNumber
    $region = $RegionsList[($RgNumber - 1) % $RegionsList.Count]
    
    Write-Log "Starting deployment for RG-$('{0:D3}' -f $RgNumber) in region $region"
    
    try {
        # Create workspace directory
        if (Test-Path $workspaceDir) {
            Remove-Item $workspaceDir -Recurse -Force
        }
        New-Item -ItemType Directory -Path $workspaceDir -Force | Out-Null
        
        # Copy Terraform files
        Copy-Item "variables.tf" "$workspaceDir\variables.tf"
        Copy-Item "main.tf" "$workspaceDir\main.tf"
        Copy-Item "outputs.tf" "$workspaceDir\outputs.tf"
        
        # Create terraform.tfvars with user configuration
        $tfvarsContent = @"
resource_group_index = $RgNumber
base_name = "$($Config.BaseResourceName)"
environment = "prod"
regions = ["$region"]
app_service_sku = "$($Config.AppServiceSku)"
"@
        Set-Content -Path "$workspaceDir\terraform.tfvars" -Value $tfvarsContent
        
        # Change to workspace directory
        Push-Location $workspaceDir
        
        # Initialize Terraform
        $initOutput = terraform init -no-color 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Terraform init failed: $($initOutput -join "`n")"
        }
        
        # Plan deployment
        $planOutput = terraform plan -no-color 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Terraform plan failed: $($planOutput -join "`n")"
        }
        
        # Apply deployment
        $applyOutput = terraform apply -auto-approve -no-color 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Terraform apply failed: $($applyOutput -join "`n")"
        }
        
        # Get outputs
        $outputs = terraform output -json 2>&1
        
        $webAppCount = $Config.AppServicePlansPerRG * $Config.WebAppsPerASP
        Write-Log "Successfully deployed RG-$('{0:D3}' -f $RgNumber) in region $region ($webAppCount web apps)" -Level "SUCCESS"
        return @{
            Success = $true
            ResourceGroup = $RgNumber
            Region = $region
            WebAppCount = $webAppCount
            Output = $outputs
        }
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log "Failed to deploy RG-$('{0:D3}' -f $RgNumber): $errorMsg" -Level "ERROR"
        return @{
            Success = $false
            ResourceGroup = $RgNumber
            Region = $region
            Error = $errorMsg
        }
    }
    finally {
        Pop-Location
    }
}

function Delete-ResourceGroup {
    param([int]$RgNumber, [string]$BaseResourceName)
    
    $rgName = "$BaseResourceName-rg-{0:D3}" -f $RgNumber
    
    Write-Log "Starting deletion for $rgName" "WARNING"
    
    try {
        # Check if resource group exists
        $rgExists = az group exists --name $rgName --output tsv 2>$null
        if ($rgExists -eq "true") {
            # Delete resource group asynchronously
            az group delete --name $rgName --yes --no-wait 2>$null
            Write-Log "Initiated deletion for $rgName" "SUCCESS"
            return @{
                Success = $true
                ResourceGroup = $rgName
                Action = "Deletion initiated"
            }
        } else {
            Write-Log "$rgName does not exist" "INFO"
            return @{
                Success = $true
                ResourceGroup = $rgName
                Action = "Already deleted"
            }
        }
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log "Failed to delete $rgName`: $errorMsg" "ERROR"
        return @{
            Success = $false
            ResourceGroup = $rgName
            Error = $errorMsg
        }
    }
}

function Cleanup-WorkspaceFiles {
    param([string]$Pattern = "deploy-workspace-rg-*")
    
    Write-Log "Cleaning up workspace files matching pattern: $Pattern" "WARNING"
    
    try {
        $workspaceDirs = Get-ChildItem -Directory -Name $Pattern -ErrorAction SilentlyContinue
        if ($workspaceDirs.Count -gt 0) {
            foreach ($dir in $workspaceDirs) {
                Write-Log "Attempting to remove workspace directory: $dir" "INFO"
                
                # First try: Standard removal
                try {
                    Remove-Item $dir -Recurse -Force -ErrorAction Stop
                    Write-Log "Successfully removed workspace directory: $dir" "SUCCESS"
                    continue
                }
                catch {
                    Write-Log "Standard removal failed for $dir`: $($_.Exception.Message)" "WARNING"
                }
                
                # Second try: Handle file locks by changing attributes and killing processes
                try {
                    # Remove read-only attributes from all files
                    Get-ChildItem $dir -Recurse -Force | ForEach-Object { 
                        if ($_.Attributes -band [System.IO.FileAttributes]::ReadOnly) {
                            $_.Attributes = $_.Attributes -band (-bnot [System.IO.FileAttributes]::ReadOnly)
                        }
                    }
                    
                    # Try removal again
                    Remove-Item $dir -Recurse -Force -ErrorAction Stop
                    Write-Log "Successfully removed workspace directory (second attempt): $dir" "SUCCESS"
                }
                catch {
                    Write-Log "Failed to completely remove $dir`: $($_.Exception.Message)" "ERROR"
                    Write-Log "Manual cleanup may be required for: $dir" "WARNING"
                }
            }
            
            # Check how many were actually cleaned up
            $remainingDirs = Get-ChildItem -Directory -Name $Pattern -ErrorAction SilentlyContinue
            $cleanedCount = $workspaceDirs.Count - $remainingDirs.Count
            
            if ($cleanedCount -gt 0) {
                Write-Log "Cleaned up $cleanedCount of $($workspaceDirs.Count) workspace directories" "SUCCESS"
            }
            if ($remainingDirs.Count -gt 0) {
                Write-Log "$($remainingDirs.Count) workspace directories require manual cleanup" "WARNING"
                foreach ($remaining in $remainingDirs) {
                    Write-Log "  - $remaining (may have file locks or permission issues)" "INFO"
                }
            }
        } else {
            Write-Log "No workspace directories found to clean up" "INFO"
        }
        
        # Also clean up any PowerShell jobs
        $jobs = Get-Job -ErrorAction SilentlyContinue
        if ($jobs.Count -gt 0) {
            Get-Job | Remove-Job -Force -ErrorAction SilentlyContinue
            Write-Log "Cleaned up $($jobs.Count) PowerShell jobs" "SUCCESS"
        }
        
        return $true
    }
    catch {
        Write-Log "Error during file cleanup: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Get-DeployedResourceGroups {
    param([string]$BaseResourceName)
    
    try {
        # Get all resource groups that match the naming pattern
        $rgList = az group list --query "[?starts_with(name, '$BaseResourceName-rg-')].{Name:name, Location:location}" --output json | ConvertFrom-Json
        return $rgList
    }
    catch {
        Write-Log "Error retrieving resource groups: $($_.Exception.Message)" "ERROR"
        return @()
    }
}

# Handle deletion requests
if ($DeleteAll -or $DeleteResources -or $CleanupFiles) {
    Write-Log "========== DELETION MODE ==========" "WARNING"
    
    if ($DeleteAll) {
        Write-Log "DELETE ALL mode: Will delete both Azure resources and local files" "WARNING"
        $DeleteResources = $true
        $CleanupFiles = $true
    }
    
    # Load configuration if specified for deletion
    if ($ConfigFile -and (Test-Path $ConfigFile)) {
        Write-Host "Loading configuration from: $ConfigFile" -ForegroundColor Cyan
        $config = Get-Content $ConfigFile | ConvertFrom-Json
        if ($config.BaseResourceName) { $BaseResourceName = $config.BaseResourceName }
        if ($config.TotalResourceGroups) { $TotalResourceGroups = $config.TotalResourceGroups }
    }
    
    if ($DeleteResources) {
        Write-Log "Finding deployed resource groups with base name: $BaseResourceName" "INFO"
        $deployedRGs = Get-DeployedResourceGroups -BaseResourceName $BaseResourceName
        
        if ($deployedRGs.Count -gt 0) {
            Write-Log "Found $($deployedRGs.Count) resource groups to delete:" "WARNING"
            foreach ($rg in $deployedRGs) {
                Write-Log "  - $($rg.Name) in $($rg.Location)" "INFO"
            }
            
            # Confirm deletion
            $confirmation = Read-Host "`nAre you sure you want to delete these $($deployedRGs.Count) resource groups? (yes/no)"
            if ($confirmation -eq "yes") {
                Write-Log "Starting deletion of $($deployedRGs.Count) resource groups..." "WARNING"
                
                $deletionResults = @()
                foreach ($rg in $deployedRGs) {
                    # Extract RG number from name
                    if ($rg.Name -match "$BaseResourceName-rg-(\d+)") {
                        $rgNumber = [int]$matches[1]
                        $result = Delete-ResourceGroup -RgNumber $rgNumber -BaseResourceName $BaseResourceName
                        $deletionResults += $result
                    }
                }
                
                Write-Log "Deletion initiated for all resource groups. This process runs asynchronously." "INFO"
                Write-Log "You can check progress with: az group list --query `"[?starts_with(name, '$BaseResourceName-rg-')]`"" "INFO"
                
                # Show deletion summary
                $successful = ($deletionResults | Where-Object { $_.Success }).Count
                $failed = ($deletionResults | Where-Object { -not $_.Success }).Count
                Write-Log "Deletion Summary: $successful initiated, $failed failed" "INFO"
            } else {
                Write-Log "Resource deletion cancelled by user" "INFO"
            }
        } else {
            Write-Log "No resource groups found with base name: $BaseResourceName" "INFO"
        }
    }
    
    if ($CleanupFiles) {
        Write-Log "Cleaning up local workspace files..." "WARNING"
        $cleanupSuccess = Cleanup-WorkspaceFiles
        if ($cleanupSuccess) {
            Write-Log "File cleanup completed successfully" "SUCCESS"
        } else {
            Write-Log "File cleanup completed with errors" "WARNING"
        }
    }
    
    Write-Log "Deletion operations completed!" "SUCCESS"
    return
}

# Main deployment logic
Write-Log "Starting deployment of $TotalResourceGroups resource groups" "INFO"
Write-Log "Selected regions: $($regions -join ', ')" "INFO" 
Write-Log "Mode: $(if ($Sequential) { 'Sequential' } else { "Parallel ($MaxParallelJobs jobs)" })" "INFO"

Write-Log "========== DEPLOYMENT PLAN ==========" "INFO"
Write-Log "Base Resource Name: $BaseResourceName" "INFO"
Write-Log "Resource Groups: $TotalResourceGroups" "INFO"
Write-Log "App Service Plans per RG: $AppServicePlansPerRG" "INFO"
Write-Log "Web Apps per ASP: $WebAppsPerASP" "INFO"
Write-Log "App Service SKU: $AppServiceSku ($vCpusPerASP vCPU each)" "INFO"
Write-Log "Total App Service Plans: $totalAppServicePlans" "INFO"
Write-Log "Total Web Apps: $totalWebApps" "INFO"
Write-Log "Total vCPUs Required: $totalVCpusRequired" "INFO"

# Create config object to pass to deployment function
$deployConfig = @{
    BaseResourceName = $BaseResourceName
    AppServicePlansPerRG = $AppServicePlansPerRG
    WebAppsPerASP = $WebAppsPerASP
    AppServiceSku = $AppServiceSku
}

$results = @()
$deployedCount = 0
$failedCount = 0
$startTime = Get-Date

if ($Sequential) {
    # Sequential deployment
    Write-Log "Running sequential deployment" "INFO"
    for ($i = 1; $i -le $TotalResourceGroups; $i++) {
        $result = Deploy-ResourceGroup -RgNumber $i -RegionsList $regions -Config $deployConfig
        $results += $result
        
        if ($result.Success) {
            $deployedCount++
            $webAppsDeployed = $deployedCount * $WebAppsPerASP * $AppServicePlansPerRG
            Write-Log "Progress: $deployedCount/$TotalResourceGroups RGs deployed ($webAppsDeployed web apps total)" "SUCCESS"
        } else {
            $failedCount++
            Write-Log "Progress: $failedCount failures so far" "ERROR"
        }
        
        # Small delay to avoid overwhelming Azure APIs
        Start-Sleep -Seconds 2
    }
} else {
    # Parallel deployment  
    Write-Log "Running parallel deployment with $MaxParallelJobs concurrent jobs" "INFO"
    
    for ($i = 1; $i -le $TotalResourceGroups; $i++) {
        # Wait if we've reached max parallel jobs
        while ((Get-Job -State Running).Count -ge $MaxParallelJobs) {
            Start-Sleep -Seconds 10
            
            # Check for completed jobs
            $completedJobs = Get-Job -State Completed
            foreach ($job in $completedJobs) {
                $result = Receive-Job $job
                $results += $result
                Remove-Job $job
                
                if ($result.Success) {
                    $deployedCount++
                } else {
                    $failedCount++
                }
                
                $runningJobs = (Get-Job -State Running).Count
                $webAppsDeployed = $deployedCount * $WebAppsPerASP * $AppServicePlansPerRG
                Write-Log "Progress: $deployedCount deployed, $failedCount failed, $runningJobs running ($webAppsDeployed web apps deployed)" "INFO"
            }
        }
        
        # Start new job
        $job = Start-Job -InitializationScript { 
            function Write-Log {
                param([string]$Message, [string]$Level = "INFO")
                $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                Write-Host "[$timestamp] [$Level] $Message"
            }
        } -ScriptBlock ${function:Deploy-ResourceGroup} -ArgumentList $i, $regions, $deployConfig
        Write-Log "Started job for RG-$('{0:D3}' -f $i)" "INFO"
        Start-Sleep -Milliseconds 500  # Small delay between job starts
    }
    
    # Wait for remaining jobs to complete
    Write-Log "Waiting for remaining jobs to complete..." "INFO"
    while ((Get-Job -State Running).Count -gt 0) {
        Start-Sleep -Seconds 10
        
        $completedJobs = Get-Job -State Completed  
        foreach ($job in $completedJobs) {
            $result = Receive-Job $job
            $results += $result
            Remove-Job $job
            
            if ($result.Success) {
                $deployedCount++
            } else {
                $failedCount++
            }
            
            $runningJobs = (Get-Job -State Running).Count
            $webAppsDeployed = $deployedCount * $WebAppsPerASP * $AppServicePlansPerRG
            Write-Log "Progress: $deployedCount deployed, $failedCount failed, $runningJobs running ($webAppsDeployed web apps deployed)" "INFO"
        }
    }
    
    # Clean up any remaining jobs
    Get-Job | Remove-Job -Force
}

$endTime = Get-Date
$duration = $endTime - $startTime

# Summary
Write-Log "========== DEPLOYMENT SUMMARY ==========" "INFO"
Write-Log "Total Resource Groups: $TotalResourceGroups" "INFO"
Write-Log "Successfully Deployed: $deployedCount" "SUCCESS"
Write-Log "Failed Deployments: $failedCount" "ERROR"
Write-Log "Total Web Apps Deployed: $($deployedCount * $WebAppsPerASP * $AppServicePlansPerRG)" "SUCCESS"
Write-Log "Success Rate: $([math]::Round(($deployedCount / $TotalResourceGroups) * 100, 2))%" "INFO"
Write-Log "Total Duration: $($duration.ToString('hh\:mm\:ss'))" "INFO"

# Show failed deployments
$failedResults = $results | Where-Object { -not $_.Success }
if ($failedResults.Count -gt 0) {
    Write-Log "========== FAILED DEPLOYMENTS ==========" "ERROR"
    foreach ($failed in $failedResults) {
        Write-Log "RG-$('{0:D3}' -f $failed.ResourceGroup), Region: $($failed.Region), Error: $($failed.Error)" "ERROR"
    }
}

# Show successful deployments by region
$successfulResults = $results | Where-Object { $_.Success }
if ($successfulResults.Count -gt 0) {
    $regionStats = $successfulResults | Group-Object Region
    Write-Log "========== REGIONAL DISTRIBUTION ==========" "INFO"
    foreach ($regionStat in $regionStats) {
        $webAppsInRegion = $regionStat.Count * $WebAppsPerASP * $AppServicePlansPerRG
        Write-Log "Region $($regionStat.Name): $($regionStat.Count) RGs deployed ($webAppsInRegion web apps)" "SUCCESS"
    }
}

Write-Log "Deployment completed!" "SUCCESS"
