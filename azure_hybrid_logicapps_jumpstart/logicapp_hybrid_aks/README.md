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
- **Service principal** with Contributor role on the subscription
- **Azure CLI extensions**: Will be installed automatically by script
  - `connectedk8s`
  - `k8s-extension`
  - `customlocation`
  - `containerapp`

### Permissions
- Contributor access to the Azure subscription
- Permission to create service principals (or use existing one)
- Ability to register Azure resource providers

## Quick Start

### Option 1: Automated Deployment (Recommended)

1. **Clone or download this repository**

2. **Update the configuration** in `DeployHybridLogicApps.ps1`:
   ```powershell
   $spnClientId = "<your-service-principal-id>"
   $spnClientSecret = "<your-service-principal-secret>"
   $spnTenantId = "<your-tenant-id>"
   $subscriptionId = "<your-subscription-id>"
   $resourceGroup = "<your-resource-group>"
   $sqlAdminPassword = "YourStrongPassword123!!"
   ```

3. **Run the deployment script**:
   ```powershell
   cd ARM/artifacts
   .\DeployHybridLogicApps.ps1
   ```

4. **Monitor deployment** - The script will create all resources (30-40 minutes)

### Option 2: Manual ARM Template Deployment

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

## Configuration Parameters

### Main Infrastructure (`azuredeploy.json`)

| Parameter | Description | Default | Required |
|-----------|-------------|---------|----------|
| `spnClientId` | Service principal client ID | - | Yes |
| `spnClientSecret` | Service principal secret | - | Yes |
| `spnTenantId` | Azure AD tenant ID | - | Yes |
| `sqlAdminPassword` | SQL Server admin password | - | Yes |
| `kubernetesVersion` | AKS Kubernetes version | 1.30.0 | No |
| `aksClusterName` | AKS cluster name | Auto-generated | No |
| `connectedClusterName` | Arc cluster name | Auto-generated | No |
| `customLocationName` | Custom location name | logicapp-hybrid-location | No |
| `connectedEnvironmentName` | Connected environment name | Auto-generated | No |
| `sqlServerName` | SQL Server name | Auto-generated | No |
| `sqlDatabaseName` | SQL Database name | LogicAppDB | No |
| `storageAccountName` | Storage account name | Auto-generated | No |
| `fileShareName` | SMB file share name | logicapp-artifacts | No |

### Logic App Template (`logicapp.json`)

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
- **Namespace**: logicapps-aca-ns
- **Features**: KEDA autoscaling, Logic Apps scaler

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

## Post-Deployment Configuration

### Accessing the Logic App

1. **Get the Logic App URL**:
   ```bash
   az containerapp show \
     --resource-group <rg-name> \
     --name <logic-app-name> \
     --query properties.configuration.ingress.fqdn
   ```

2. **Test with sample workflow**:
   ```powershell
   Invoke-RestMethod -Uri "https://<logic-app-fqdn>/api/workflows/sample/triggers/manual/invoke" `
     -Method Post `
     -Body (@{ name = "Test" } | ConvertTo-Json) `
     -ContentType "application/json"
   ```

### Deploying Workflows

1. **Copy workflow to SMB share**:
   ```powershell
   # Mount the file share
   $storageAccount = "<storage-account-name>"
   $shareName = "<file-share-name>"
   $key = "<storage-account-key>"
   
   # Use Azure CLI or Azure Storage Explorer to upload
   az storage file upload \
     --account-name $storageAccount \
     --account-key $key \
     --share-name $shareName \
     --source sample-workflow.json \
     --path <logic-app-name>/workflow.json
   ```

2. **Restart the Logic App** to pick up changes:
   ```bash
   kubectl rollout restart deployment -n logicapps-aca-ns
   ```

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
   - Verify service principal has Contributor role
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

## Cost Estimation

Approximate monthly costs (East US region):
- **AKS**: ~$220 (3x Standard_D4s_v3 nodes)
- **SQL Database**: ~$15 (Standard S0)
- **Storage Account**: ~$5 (5 TB file share)
- **Log Analytics**: ~$5 (1 GB/day)
- **Azure Arc**: Free for AKS clusters
- **Container Apps**: Included with Arc
- **Total**: ~$245/month

Costs vary by region and usage. Use [Azure Pricing Calculator](https://azure.microsoft.com/pricing/calculator/) for accurate estimates.

## Security Best Practices

1. **Service Principal**: Use managed identity where possible
2. **SQL Server**: Enable Azure AD authentication
3. **Storage Account**: Use private endpoints
4. **AKS**: Enable Azure Policy and Microsoft Defender
5. **Secrets**: Store in Azure Key Vault, not in code
6. **Network**: Implement network policies and ingress filtering

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

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](../../CONTRIBUTING.md) for guidelines.

## License

This project is licensed under the MIT License - see [LICENSE](../../LICENSE) for details.
