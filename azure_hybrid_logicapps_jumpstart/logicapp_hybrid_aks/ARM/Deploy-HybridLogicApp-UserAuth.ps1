<#
.SYNOPSIS
    Deploys Hybrid Logic Apps infrastructure on Azure Arc-enabled Kubernetes.

.DESCRIPTION
    This script automates the complete deployment of:
    - AKS cluster with Arc enablement
    - Azure SQL Server and Database
    - Storage Account with SMB file share
    - Container Apps connected environment
    - Hybrid Logic App

.PARAMETER SubscriptionId
    Azure subscription ID where resources will be deployed.

.PARAMETER ResourceGroup
    Name of the resource group to create or use.

.PARAMETER Location
    Azure region for deployment (e.g., westeurope, eastus).

.PARAMETER SqlAdminPassword
    Password for SQL Server admin account (must meet complexity requirements).

.PARAMETER KubernetesVersion
    Optional. Kubernetes version for AKS cluster. Default is 1.32.9.

.PARAMETER SqlAdminUsername
    Optional. SQL Server admin username. Default is 'sqladmin'.

.PARAMETER SqlDatabaseName
    Optional. SQL Database name. Default is 'LogicAppDB'.

.PARAMETER FileShareName
    Optional. Storage file share name. Default is 'logicapp-artifacts'.

.EXAMPLE
    .\Deploy-HybridLogicApp-UserAuth.ps1 -SubscriptionId "your-sub-id" -ResourceGroup "my-rg" -Location "westeurope" -SqlAdminPassword (ConvertTo-SecureString "MyP@ssw0rd123!" -AsPlainText -Force)

.EXAMPLE
    .\Deploy-HybridLogicApp-UserAuth.ps1 -SubscriptionId "your-sub-id" -ResourceGroup "my-rg" -Location "eastus" -SqlAdminPassword (ConvertTo-SecureString "MyP@ssw0rd123!" -AsPlainText -Force) -KubernetesVersion "1.31.0"

.EXAMPLE
    # Full example with all optional parameters
    .\Deploy-HybridLogicApp-UserAuth.ps1 `
        -SubscriptionId "2ba690bf-a85f-4cbc-b4cb-3bfead7e2f97" `
        -ResourceGroup "my-logicapp-rg" `
        -Location "westeurope" `
        -SqlAdminPassword (ConvertTo-SecureString "MyP@ssw0rd123!" -AsPlainText -Force) `
        -KubernetesVersion "1.32.9" `
        -SqlAdminUsername "sqladmin" `
        -SqlDatabaseName "LogicAppDB" `
        -FileShareName "logicapp-artifacts" `
        -AksClusterName "my-aks-77501" `
        -ConnectedClusterName "my-arc-77501" `
        -ExtensionName "my-logicapps-ext" `
        -Namespace "my-logicapps-ns" `
        -CustomLocationName "my-location-77501" `
        -ConnectedEnvironmentName "my-env-77501" `
        -SqlServerName "mylogicappsql77501" `
        -StorageAccountName "mylogicappsa77501" `
        -StorageMountName "my-smb-mount" `
        -WorkspaceName "my-workspace-77501" `
        -LogicAppName "my-logicapp-77501"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, HelpMessage="Azure subscription ID")]
    [ValidateNotNullOrEmpty()]
    [string]$SubscriptionId,

    [Parameter(Mandatory=$true, HelpMessage="Resource group name")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(Mandatory=$true, HelpMessage="Azure region (e.g., westeurope, eastus)")]
    [ValidateNotNullOrEmpty()]
    [string]$Location,

    [Parameter(Mandatory=$true, HelpMessage="SQL Server admin password")]
    [ValidateNotNullOrEmpty()]
    [SecureString]$SqlAdminPassword,

    [Parameter(Mandatory=$false, HelpMessage="Kubernetes version for AKS")]
    [ValidateNotNullOrEmpty()]
    [string]$KubernetesVersion = "1.32.9",

    [Parameter(Mandatory=$false, HelpMessage="SQL Server admin username")]
    [ValidateNotNullOrEmpty()]
    [string]$SqlAdminUsername = "sqladmin",

    [Parameter(Mandatory=$false, HelpMessage="SQL Database name")]
    [ValidateNotNullOrEmpty()]
    [string]$SqlDatabaseName = "LogicAppDB",

    [Parameter(Mandatory=$false, HelpMessage="Storage file share name")]
    [ValidateNotNullOrEmpty()]
    [string]$FileShareName = "logicapp-artifacts",

    [Parameter(Mandatory=$false, HelpMessage="AKS cluster name")]
    [ValidateNotNullOrEmpty()]
    [string]$AksClusterName = "logicapp-aks" ,

    [Parameter(Mandatory=$false, HelpMessage="Arc-enabled cluster name")]
    [ValidateNotNullOrEmpty()]
    [string]$ConnectedClusterName = "logicapp-arc" ,

    [Parameter(Mandatory=$false, HelpMessage="Container Apps extension name")]
    [ValidateNotNullOrEmpty()]
    [string]$ExtensionName = "logicapps-ext",

    [Parameter(Mandatory=$false, HelpMessage="Kubernetes namespace for Logic Apps")]
    [ValidateNotNullOrEmpty()]
    [string]$Namespace = "logicapps-ns",

    [Parameter(Mandatory=$false, HelpMessage="Custom location name")]
    [ValidateNotNullOrEmpty()]
    [string]$CustomLocationName = "logicapp-location-" + (Get-Random -Maximum 99999),

    [Parameter(Mandatory=$false, HelpMessage="Connected environment name")]
    [ValidateNotNullOrEmpty()]
    [string]$ConnectedEnvironmentName = "logicapp-env-" + (Get-Random -Maximum 99999),

    [Parameter(Mandatory=$false, HelpMessage="SQL Server name")]
    [ValidateNotNullOrEmpty()]
    [string]$SqlServerName = "logicappsql" + (Get-Random -Maximum 999999),

    [Parameter(Mandatory=$false, HelpMessage="Storage account name")]
    [ValidateNotNullOrEmpty()]
    [string]$StorageAccountName = "logicappsa" + (Get-Random -Maximum 999999),

    [Parameter(Mandatory=$false, HelpMessage="Storage mount name")]
    [ValidateNotNullOrEmpty()]
    [string]$StorageMountName = "logicapp-smb-mount",

    [Parameter(Mandatory=$false, HelpMessage="Log Analytics workspace name")]
    [ValidateNotNullOrEmpty()]
    [string]$WorkspaceName = "logicapp-ws" ,

    [Parameter(Mandatory=$false, HelpMessage="Logic App name")]
    [ValidateNotNullOrEmpty()]
    [string]$LogicAppName = "logicapp-hybrid"
)

# Convert SecureString password to plain text for use in connection strings
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SqlAdminPassword)
$sqlAdminPasswordPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)

# All resource names are configured via parameters
# No variable assignments needed - using parameter values directly throughout the script

# ============================================================================
# SCRIPT EXECUTION - Do not modify below this line
# ============================================================================

$ErrorActionPreference = "Continue"
Start-Transcript -Path ".\HybridLogicAppSetup-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host "Azure Arc-enabled Hybrid Logic Apps - Complete Deployment" -ForegroundColor Cyan
Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Configuration:" -ForegroundColor Yellow
Write-Host "  Subscription: $SubscriptionId" -ForegroundColor White
Write-Host "  Resource Group: $ResourceGroup" -ForegroundColor White
Write-Host "  Location: $Location" -ForegroundColor White
Write-Host "  Kubernetes Version: $KubernetesVersion" -ForegroundColor White
Write-Host ""

# Set subscription
Write-Host "[1/18] Setting Azure subscription..." -ForegroundColor Yellow
az account set --subscription $SubscriptionId
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to set subscription. Please ensure you're logged in with 'az login'" -ForegroundColor Red
    Stop-Transcript
    exit 1
}
Write-Host "  Subscription set successfully" -ForegroundColor Green

# Check if resource group exists, create if not
Write-Host "[2/18] Checking resource group..." -ForegroundColor Yellow
$rgExists = az group exists --name $ResourceGroup
if ($rgExists -eq "true") {
    Write-Host "  Resource group '$ResourceGroup' already exists" -ForegroundColor Cyan
} else {
    Write-Host "  Creating resource group '$ResourceGroup' in '$Location'..." -ForegroundColor Cyan
    az group create --name $ResourceGroup --location $Location
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  Resource group created successfully!" -ForegroundColor Green
    } else {
        Write-Host "  ERROR: Failed to create resource group" -ForegroundColor Red
        Stop-Transcript
        exit 1
    }
}

# Register required resource providers
Write-Host "[3/18] Registering Azure resource providers..." -ForegroundColor Yellow
$providers = @(
    "Microsoft.ContainerService",
    "Microsoft.Kubernetes",
    "Microsoft.KubernetesConfiguration",
    "Microsoft.ExtendedLocation",
    "Microsoft.App",
    "Microsoft.OperationalInsights",
    "Microsoft.Web",
    "Microsoft.Sql",
    "Microsoft.Storage"
)

foreach ($provider in $providers) {
    Write-Host "  Registering $provider..." -ForegroundColor Cyan
    az provider register --namespace $provider --wait
}
Write-Host "  All providers registered" -ForegroundColor Green

# Install Azure CLI extensions
Write-Host "[4/18] Installing Azure CLI extensions..." -ForegroundColor Yellow
az extension add --name connectedk8s --upgrade --yes 2>&1 | Out-Null
az extension add --name k8s-extension --upgrade --yes 2>&1 | Out-Null
az extension add --name customlocation --upgrade --yes 2>&1 | Out-Null
az extension add --name containerapp --upgrade --yes 2>&1 | Out-Null
Write-Host "  Extensions installed" -ForegroundColor Green

# Create Log Analytics workspace
Write-Host "[5/18] Creating Log Analytics workspace..." -ForegroundColor Yellow
az monitor log-analytics workspace create `
    --resource-group $ResourceGroup `
    --workspace-name $WorkspaceName `
    --location $Location | Out-Null
Write-Host "  Log Analytics workspace created: $WorkspaceName" -ForegroundColor Green

# Create AKS cluster
Write-Host "[6/18] Creating AKS cluster (this may take 10-15 minutes)..." -ForegroundColor Yellow
az aks create `
    --resource-group $ResourceGroup `
    --name $AksClusterName `
    --kubernetes-version $KubernetesVersion `
    --node-count 3 `
    --node-vm-size Standard_D4s_v3 `
    --enable-managed-identity `
    --enable-cluster-autoscaler `
    --min-count 1 `
    --max-count 6 `
    --location $Location `
    --no-wait

Write-Host "  AKS cluster creation initiated..." -ForegroundColor Cyan
Write-Host "  Waiting for cluster to be ready..." -ForegroundColor Yellow
az aks wait --resource-group $ResourceGroup --name $AksClusterName --created --interval 30 --timeout 1200
Write-Host "  AKS cluster created successfully: $AksClusterName" -ForegroundColor Green

# Get AKS credentials
Write-Host "[7/18] Configuring kubectl access to AKS cluster..." -ForegroundColor Yellow
az aks get-credentials --resource-group $ResourceGroup --name $AksClusterName --admin --overwrite-existing
kubectl get nodes
Write-Host "  kubectl configured" -ForegroundColor Green

# Create SQL Server and Database
Write-Host "[8/18] Creating Azure SQL Server and Database..." -ForegroundColor Yellow
az sql server create `
    --resource-group $ResourceGroup `
    --name $SqlServerName `
    --location $Location `
    --admin-user $SqlAdminUsername `
    --admin-password $sqlAdminPasswordPlain | Out-Null

az sql server firewall-rule create `
    --resource-group $ResourceGroup `
    --server $SqlServerName `
    --name AllowAzureServices `
    --start-ip-address 0.0.0.0 `
    --end-ip-address 0.0.0.0 | Out-Null

az sql db create `
    --resource-group $ResourceGroup `
    --server $SqlServerName `
    --name $SqlDatabaseName `
    --service-objective S0 | Out-Null

Write-Host "  SQL Server and Database created: $SqlServerName" -ForegroundColor Green

# Create Storage Account
Write-Host "[9/18] Creating Storage Account with SMB file share..." -ForegroundColor Yellow
az storage account create `
    --resource-group $ResourceGroup `
    --name $StorageAccountName `
    --location $Location `
    --sku Standard_LRS `
    --kind StorageV2 | Out-Null

$storageAccountKey = az storage account keys list `
    --resource-group $ResourceGroup `
    --account-name $StorageAccountName `
    --query "[0].value" -o tsv

az storage share create `
    --name $FileShareName `
    --account-name $StorageAccountName `
    --account-key $storageAccountKey `
    --quota 5120 | Out-Null

# Create subdirectory for Logic App in the file share
az storage directory create `
    --name $LogicAppName `
    --share-name $FileShareName `
    --account-name $StorageAccountName `
    --account-key $storageAccountKey | Out-Null

Write-Host "  Storage Account and file share created: $StorageAccountName" -ForegroundColor Green
Write-Host "  Subdirectory created for Logic App: $FileShareName\$LogicAppName" -ForegroundColor Green

# Install SMB CSI driver
Write-Host "[10/18] Installing SMB CSI driver..." -ForegroundColor Yellow
helm repo add csi-driver-smb https://raw.githubusercontent.com/kubernetes-csi/csi-driver-smb/master/charts 2>&1 | Out-Null
helm repo update 2>&1 | Out-Null
helm install csi-driver-smb csi-driver-smb/csi-driver-smb --namespace kube-system --version v1.15.0 2>&1 | Out-Null
Start-Sleep -Seconds 10
kubectl get csidriver
Write-Host "  SMB CSI driver installed" -ForegroundColor Green

# Connect cluster to Azure Arc
Write-Host "[11/18] Connecting AKS cluster to Azure Arc (5-10 minutes)..." -ForegroundColor Yellow
az connectedk8s connect `
    --resource-group $ResourceGroup `
    --name $ConnectedClusterName `
    --location $Location

Write-Host "  Arc connection completed: $ConnectedClusterName" -ForegroundColor Green

# Get Log Analytics workspace credentials
Write-Host "[12/18] Getting Log Analytics workspace credentials..." -ForegroundColor Yellow
$workspaceId = az monitor log-analytics workspace show `
    --resource-group $ResourceGroup `
    --workspace-name $WorkspaceName `
    --query customerId -o tsv

$workspaceKey = az monitor log-analytics workspace get-shared-keys `
    --resource-group $ResourceGroup `
    --workspace-name $WorkspaceName `
    --query primarySharedKey -o tsv

$workspaceIdEncoded = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($workspaceId))
$workspaceKeyEncoded = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($workspaceKey))
Write-Host "  Credentials retrieved" -ForegroundColor Green

# Install Container Apps extension
Write-Host "[13/18] Installing Azure Container Apps extension (5-10 minutes)..." -ForegroundColor Yellow
az k8s-extension create `
    --resource-group $ResourceGroup `
    --name $ExtensionName `
    --cluster-type connectedClusters `
    --cluster-name $ConnectedClusterName `
    --extension-type 'Microsoft.App.Environment' `
    --release-train stable `
    --auto-upgrade-minor-version true `
    --scope cluster `
    --release-namespace $Namespace `
    --configuration-settings "Microsoft.CustomLocation.ServiceAccount=default" `
    --configuration-settings "appsNamespace=$Namespace" `
    --configuration-settings "keda.enabled=true" `
    --configuration-settings "keda.logicAppsScaler.enabled=true" `
    --configuration-settings "keda.logicAppsScaler.replicaCount=1" `
    --configuration-settings "containerAppController.api.functionsServerEnabled=true" `
    --configuration-settings "envoy.externalServiceAzureILB=false" `
    --configuration-settings "functionsProxyApiConfig.enabled=true" `
    --configuration-settings "clusterName=$ConnectedEnvironmentName" `
    --configuration-settings "envoy.annotations.service.beta.kubernetes.io/azure-load-balancer-resource-group=$ResourceGroup" `
    --configuration-settings "logProcessor.appLogs.destination=log-analytics" `
    --configuration-protected-settings "logProcessor.appLogs.logAnalyticsConfig.customerId=$workspaceIdEncoded" `
    --configuration-protected-settings "logProcessor.appLogs.logAnalyticsConfig.sharedKey=$workspaceKeyEncoded" | Out-Null

$extensionId = az k8s-extension show `
    --cluster-type connectedClusters `
    --cluster-name $ConnectedClusterName `
    --resource-group $ResourceGroup `
    --name $ExtensionName `
    --query id -o tsv

Write-Host "  Waiting for extension installation..." -ForegroundColor Yellow
az resource wait `
    --ids $extensionId `
    --custom "properties.provisioningState!='Pending'" `
    --api-version "2020-07-01-preview" `
    --timeout 600

Write-Host "  Extension installed: $ExtensionName" -ForegroundColor Green

# Create custom location
Write-Host "[14/18] Creating custom location..." -ForegroundColor Yellow
$connectedClusterId = az connectedk8s show `
    --resource-group $ResourceGroup `
    --name $ConnectedClusterName `
    --query id -o tsv

az customlocation create `
    --resource-group $ResourceGroup `
    --name $CustomLocationName `
    --host-resource-id $connectedClusterId `
    --namespace $Namespace `
    --cluster-extension-ids $extensionId `
    --location $Location | Out-Null

Start-Sleep -Seconds 15

$customLocationId = az customlocation show `
    --resource-group $ResourceGroup `
    --name $CustomLocationName `
    --query id -o tsv

Write-Host "  Custom location created: $CustomLocationName" -ForegroundColor Green

# Create Container Apps connected environment
Write-Host "[15/18] Creating Container Apps connected environment..." -ForegroundColor Yellow
az containerapp connected-env create `
    --resource-group $ResourceGroup `
    --name $ConnectedEnvironmentName `
    --custom-location $customLocationId `
    --location $Location | Out-Null

$connectedEnvId = az containerapp connected-env show `
    --resource-group $ResourceGroup `
    --name $ConnectedEnvironmentName `
    --query id -o tsv

Write-Host "  Connected environment created: $ConnectedEnvironmentName" -ForegroundColor Green

# Create SMB storage mount on Connected Environment
Write-Host "[16/18] Creating SMB storage mount on Connected Environment..." -ForegroundColor Yellow

$storageMountTemplateFile = ".\storage-mount-template.json"

az deployment group create `
    --resource-group $ResourceGroup `
    --template-file $storageMountTemplateFile `
    --parameters connectedEnvironmentName="$ConnectedEnvironmentName" `
                 storageMountName="$StorageMountName" `
                 storageAccountName="$StorageAccountName" `
                 storageAccountKey="$storageAccountKey" `
                 fileShareName="$FileShareName" `
                 logicAppName="$LogicAppName" `
    --name "storage-mount-$(Get-Date -Format 'yyyyMMdd-HHmmss')" | Out-Null

Write-Host "  SMB storage mount created: $StorageMountName" -ForegroundColor Green

# Create Logic App using ARM template
Write-Host "[17/18] Creating Hybrid Logic App using ARM template..." -ForegroundColor Yellow

$sqlConnectionString = "Server=tcp:$SqlServerName.database.windows.net,1433;Initial Catalog=$SqlDatabaseName;User ID=$SqlAdminUsername;Password=$sqlAdminPasswordPlain;Encrypt=True;"

$logicAppTemplateFile = ".\logicapp-template.json"

az deployment group create `
    --resource-group $ResourceGroup `
    --template-file $logicAppTemplateFile `
    --parameters logicAppName="$LogicAppName" `
                 customLocationName="$CustomLocationName" `
                 connectedEnvironmentName="$ConnectedEnvironmentName" `
                 storageAccountName="$StorageAccountName" `
                 storageAccountKey="$storageAccountKey" `
                 fileShareName="$FileShareName" `
                 sqlConnectionString="$sqlConnectionString" `
                 location="$Location" `
    --name "logicapp-deployment-$(Get-Date -Format 'yyyyMMddHHmmss')"

if ($LASTEXITCODE -eq 0) {
    Write-Host "  Logic App created: $LogicAppName" -ForegroundColor Green
} else {
    Write-Host "  ERROR: Failed to create Logic App" -ForegroundColor Red
    Write-Host "  Check the deployment logs for details" -ForegroundColor Yellow
}

# Verify Logic App deployment
Write-Host "[18/18] Verifying Logic App deployment..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

$logicAppStatus = az containerapp show `
    --name $LogicAppName `
    --resource-group $ResourceGroup `
    --query "{Name:name, Status:properties.provisioningState, Running:properties.runningStatus, Image:properties.template.containers[0].image}" `
    -o json 2>$null | ConvertFrom-Json

if ($logicAppStatus) {
    Write-Host "  Logic App Status:" -ForegroundColor Cyan
    Write-Host "    Name: $($logicAppStatus.Name)" -ForegroundColor White
    Write-Host "    Provisioning State: $($logicAppStatus.Status)" -ForegroundColor White
    Write-Host "    Running Status: $($logicAppStatus.Running)" -ForegroundColor White
    Write-Host "    Container Image: $($logicAppStatus.Image)" -ForegroundColor White
} else {
    Write-Host "  Logic App verification pending - check Azure Portal for status" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=====================================================================" -ForegroundColor Green
Write-Host "DEPLOYMENT COMPLETE!" -ForegroundColor Green
Write-Host "=====================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Resources Created:" -ForegroundColor Cyan
Write-Host "  Resource Group: $ResourceGroup" -ForegroundColor White
Write-Host "  AKS Cluster: $AksClusterName" -ForegroundColor White
Write-Host "  Arc-enabled Cluster: $ConnectedClusterName" -ForegroundColor White
Write-Host "  Custom Location: $CustomLocationName" -ForegroundColor White
Write-Host "  Connected Environment: $ConnectedEnvironmentName" -ForegroundColor White
Write-Host "  Storage Mount: $StorageMountName" -ForegroundColor White
Write-Host "  SQL Server: $SqlServerName.database.windows.net" -ForegroundColor White
Write-Host "  SQL Database: $SqlDatabaseName" -ForegroundColor White
Write-Host "  Storage Account: $StorageAccountName" -ForegroundColor White
Write-Host "  Logic App: $LogicAppName" -ForegroundColor White
Write-Host ""
Write-Host "Portal URL:" -ForegroundColor Cyan
Write-Host "  https://portal.azure.com/#resource/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.App/containerapps/$LogicAppName" -ForegroundColor Yellow
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Access Logic App in Azure Portal (URL above)" -ForegroundColor White
Write-Host "  2. Create workflows in the Logic App designer" -ForegroundColor White
Write-Host "  3. Use the pre-configured SQL connection for data operations" -ForegroundColor White
Write-Host ""

Stop-Transcript

Write-Host "Log file saved to current directory" -ForegroundColor Green
