# Azure Arc-enabled Hybrid Logic Apps on AKS

This solution deploys Azure Logic Apps in a hybrid configuration using Azure Arc-enabled Kubernetes, running on Azure Kubernetes Service (AKS) with SQL Server backend and SMB file share storage.

## Architecture Overview

The deployment creates:
- **Azure Kubernetes Service (AKS)** - Managed Kubernetes cluster
- **Azure Arc-enabled Kubernetes** - Connection layer to Azure Arc services
- **Azure Container Apps Extension** - Enables Logic Apps hosting on Kubernetes
- **Azure SQL Database** - Stores workflow state and metadata
- **Azure Storage Account** - SMB file share for workflow artifacts
- **Custom Location** - Azure location abstraction for Arc-enabled services
- **Connected Environment** - Container Apps environment on Arc-enabled cluster
- **Hybrid Logic App** - Standard Logic App running on Kubernetes

## Prerequisites

Before deploying, ensure you have:

### Tools & Software
- **Azure CLI** version 2.40.0 or later ([Install](https://docs.microsoft.com/cli/azure/install-azure-cli))
- **kubectl** version 1.28.0 or later ([Install](https://kubernetes.io/docs/tasks/tools/))
- **Helm** version 3.0.0 or later ([Install](https://helm.sh/docs/intro/install/))
- **PowerShell** 5.1 or later (Windows) or PowerShell Core 7+ (cross-platform)

### Azure Requirements
- **Active Azure subscription**
- **Azure CLI extensions**: Will be installed automatically by script
  - `connectedk8s`
  - `k8s-extension`
  - `customlocation`
  - `containerapp`

### Permissions
- Contributor access to the Azure subscription
- Ability to register Azure resource providers

## Quick Start

### Automated Deployment with User Authentication

The `Deploy-HybridLogicApp-UserAuth.ps1` script provides a fully automated deployment using Azure CLI with interactive user authentication.

1. **Clone or download this repository**

2. **Run the deployment script**:
   ```powershell
   cd ARM
   .\Deploy-HybridLogicApp-UserAuth.ps1 `
       -SubscriptionId "your-subscription-id" `
       -ResourceGroup "logicapp-hybrid-rg" `
       -Location "westeurope" `
       -SqlAdminPassword (ConvertTo-SecureString "YourStrongPassword123!" -AsPlainText -Force)
   ```

3. **Monitor deployment** - The script will:
   - Prompt for Azure login (browser-based authentication)
   - Create all resources automatically (30-45 minutes)
   - Display progress for each of the 19 deployment steps

#### Deployment Steps

The automated script performs the following steps:

1. **[1/19] Login to Azure** - Interactive browser-based authentication
2. **[2/19] Set Azure subscription** - Configure the target subscription
3. **[3/19] Check/create resource group** - Ensure resource group exists
4. **[4/19] Register resource providers** - Enable required Azure services
5. **[5/19] Install Azure CLI extensions** - Add connectedk8s, k8s-extension, customlocation, containerapp
6. **[6/19] Create Log Analytics workspace** - Set up monitoring and logging
7. **[7/19] Create AKS cluster** - Deploy managed Kubernetes (10-15 minutes)
8. **[8/19] Configure kubectl** - Set up cluster access credentials
9. **[9/19] Create SQL Server and Database** - Deploy backend database
10. **[10/19] Create Storage Account** - Set up SMB file share for artifacts
11. **[11/19] Install SMB CSI driver** - Enable SMB mount in Kubernetes
12. **[12/19] Connect to Azure Arc** - Enable Arc services (5-10 minutes)
13. **[13/19] Get Log Analytics credentials** - Retrieve workspace keys
14. **[14/19] Install Container Apps extension** - Deploy Logic Apps runtime (5-10 minutes)
15. **[15/19] Create custom location** - Set up Azure location abstraction
16. **[16/19] Create connected environment** - Deploy Container Apps environment
17. **[17/19] Create SMB storage mount** - Configure persistent storage
18. **[18/19] Deploy Logic App** - Create the Logic App using ARM template
19. **[19/19] Verify deployment** - Check Logic App status and configuration

#### Optional Parameters

You can customize the deployment with additional parameters:

```powershell
.\Deploy-HybridLogicApp-UserAuth.ps1 `
    -SubscriptionId "2ba690bf-a85f-4cbc-b4cb-3bfead7e2f97" `
    -ResourceGroup "my-logicapp-rg" `
    -Location "westeurope" `
    -SqlAdminPassword (ConvertTo-SecureString "MyP@ssw0rd123!" -AsPlainText -Force) `
    -KubernetesVersion "1.32.9" `
    -SqlAdminUsername "sqladmin" `
    -SqlDatabaseName "LogicAppDB" `
    -FileShareName "logicapp-artifacts" `
    -AksClusterName "my-aks-cluster" `
    -ConnectedClusterName "my-arc-cluster" `
    -ExtensionName "logicapps-ext" `
    -Namespace "logicapps-ns" `
    -CustomLocationName "my-custom-location" `
    -ConnectedEnvironmentName "my-connected-env" `
    -SqlServerName "mylogicappsql" `
    -StorageAccountName "mylogicappsa" `
    -StorageMountName "logicapp-smb-mount" `
    -WorkspaceName "my-workspace" `
    -LogicAppName "my-logicapp"
```


For manual control over individual resources:

1. **Create a resource group**:
   ```bash
   az group create --name logicapp-hybrid-rg --location eastus
   ```

2. **Deploy the infrastructure**:
   ```bash
   az deployment group create \
     --resource-group logicapp-hybrid-rg \
     --template-file ARM/azuredeploy.json \
     --parameters ARM/azuredeploy.parameters.json
   ```

3. **Deploy the Logic App** (after infrastructure is ready):
   ```bash
   az deployment group create \
     --resource-group logicapp-hybrid-rg \
     --template-file ARM/logicapp.json \
     --parameters ARM/logicapp.parameters.json
   ```




| Parameter | Description | Default | Required |
|-----------|-------------|---------|----------|
| `logicAppName` | Logic App name | - | Yes |
| `customLocationName` | Custom location name | - | Yes |
| `connectedEnvironmentName` | Connected environment name | - | Yes |
| `storageAccountName` | Storage account name | - | Yes |
| `fileShareName` | SMB file share name | - | Yes |
| `storageAccountKey` | Storage account key | - | Yes |
| `sqlConnectionString` | SQL connection string | - | Yes |
| `minReplicas` | Minimum replicas | 1 | No |
| `maxReplicas` | Maximum replicas | 3 | No |
| `cpu` | CPU allocation | 0.5 | No |
| `memory` | Memory allocation | 1Gi | No |

## Deployment Components

### 1. Azure Kubernetes Service (AKS)
- **VM Size**: Standard_D4s_v3
- **Node Count**: 3 (autoscaling 1-6)
- **Kubernetes Version**: 1.30.0
- **Add-ons**: Monitoring (Log Analytics)

### 2. Azure SQL Database
- **Tier**: Standard S0
- **Purpose**: Stores workflow run history and state
- **Firewall**: Azure services allowed
- **Connection**: Encrypted with TLS 1.2

### 3. Storage Account (SMB File Share)
- **Type**: StorageV2 (Standard LRS)
- **Protocol**: SMB 3.0
- **Quota**: 5 TB
- **Purpose**: Stores workflow definitions and artifacts
- **Mount**: Via SMB CSI driver in Kubernetes

### 4. Azure Arc Connection
- **Purpose**: Connects AKS to Azure Arc services
- **Extensions**: Container Apps (Microsoft.App.Environment)
- **Namespace**: Configurable (default: logicapps-ns)
- **Features**: 
  - KEDA autoscaling enabled
  - Logic Apps scaler with replica count of 1
  - Functions server API enabled
  - Functions proxy API configuration
  - Log Analytics integration for application logs
  - Azure Load Balancer annotations

### 5. Container Apps Connected Environment
- **Type**: Arc-enabled
- **Ingress**: External (HTTPS)
- **Scaling**: KEDA-based autoscaling
- **Monitoring**: Log Analytics integration

### 6. Hybrid Logic App
- **Type**: Standard (Container Apps)
- **Image**: mcr.microsoft.com/azurelogicapps/logicapps-base:validation
- **Kind**: workflowapp
- **Storage**: SMB volume mount for /home/site/wwwroot
- **State**: SQL Database backend






### Monitoring

1. **View logs in Log Analytics**:
   ```bash
   az monitor log-analytics query \
     --workspace <workspace-id> \
     --analytics-query "ContainerAppConsoleLogs_CL | where ContainerAppName_s == '<logic-app-name>' | order by TimeGenerated desc | take 100"
   ```

2. **Check pod status**:
   ```bash
   kubectl get pods -n logicapps-aca-ns
   kubectl logs -n logicapps-aca-ns <pod-name>
   ```

## Testing

We provide comprehensive testing scripts:

### Pre-Deployment Tests
```powershell
cd ARM/artifacts
.\TestDeployment.ps1 -TestMode PreDeployment
```

Validates:
- Azure CLI, kubectl, Helm installations
- ARM template syntax
- Parameters configuration
- Azure login status

### Post-Deployment Tests
```powershell
.\TestDeployment.ps1 -TestMode PostDeployment -ResourceGroup <rg-name>
```

Validates:
- All Azure resources created
- Arc connection established
- Extension installed
- Pods running
- SQL and Storage accessible

See [TESTING.md](TESTING.md) for detailed testing guide.

## Troubleshooting

### Common Issues

1. **Arc connection fails**
   
   - Check network connectivity from AKS
   - Ensure resource providers are registered

2. **Extension installation pending**
   - Wait 5-10 minutes (normal for first-time installation)
   - Check: `az k8s-extension show --cluster-type connectedClusters --cluster-name <name> --resource-group <rg> --name <extension-name>`

3. **Logic App not accessible**
   - Verify custom location created
   - Check pods running: `kubectl get pods -n logicapps-aca-ns`
   - Review logs: `kubectl logs -n logicapps-aca-ns <pod-name>`

4. **SQL connection fails**
   - Verify firewall rules allow Azure services
   - Test connection: `Test-NetConnection -ComputerName <server>.database.windows.net -Port 1433`
   - Check connection string in Logic App configuration

### Get Support

- **GitHub Issues**: [microsoft/azure_arc](https://github.com/microsoft/azure_arc/issues)
- **Documentation**: [Hybrid Logic Apps](https://learn.microsoft.com/azure/logic-apps/set-up-standard-workflows-hybrid-deployment-requirements)
- **Azure Support**: [Create support request](https://portal.azure.com/#create/Microsoft.Support)


## Cleanup

To delete all resources:

```bash
# Delete resource group (WARNING: Deletes ALL resources)
az group delete --name <resource-group-name> --yes --no-wait

# Or selectively delete resources
az aks delete --resource-group <rg> --name <aks-cluster> --yes
az connectedk8s delete --resource-group <rg> --name <arc-cluster>
az sql server delete --resource-group <rg> --name <sql-server>
az storage account delete --resource-group <rg> --name <storage-account>
```

## Additional Resources

- [Azure Arc-enabled Kubernetes](https://learn.microsoft.com/azure/azure-arc/kubernetes/overview)
- [Azure Container Apps on Arc](https://learn.microsoft.com/azure/container-apps/azure-arc-overview)
- [Logic Apps Standard](https://learn.microsoft.com/azure/logic-apps/single-tenant-overview-compare)
- [Hybrid Logic Apps Requirements](https://learn.microsoft.com/azure/logic-apps/set-up-standard-workflows-hybrid-deployment-requirements)




