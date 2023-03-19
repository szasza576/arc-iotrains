#!/bin/bash

if [ -z ${ResourceGroup+x} ]; then ResourceGroup="Arc-IoTrains"; fi
if [ -z ${Location+x} ]; then Location="westeurope"; fi
if [ -z ${LogAnalyticsName+x} ]; then LogAnalyticsName="iotrains-logs"; fi
if [ -z ${ClusterName+x} ]; then ClusterName="iotrains-k8s"; fi
if [ -z ${AppExtName+x} ]; then AppExtName="appservice-ext"; fi
if [ -z ${AppExtNamespace+x} ]; then AppExtNamespace="iotrains-apps"; fi
if [ -z ${AppEnvironmentName+x} ]; then AppEnvironmentName="iotrains-appservices"; fi
if [ -z ${AppCustomLocationName+x} ]; then AppCustomLocationName="iotrains-app-site"; fi
if [ -z ${StorageClass+x} ]; then StorageClass="default"; fi
if [ -z ${ACRName+x} ]; then ACRName="iotrainsacr"; fi
if [ -z ${AMLExtName+x} ]; then AMLExtName="iotrains-ml"; fi
if [ -z ${AMLIdentityName+x} ]; then AMLIdentityName="iotrains-ml-identity"; fi
if [ -z ${ArcMLExtIdentityName+x} ]; then ArcMLExtIdentityName="iotrains-arc-identity"; fi
if [ -z ${MLWorkspaceName+x} ]; then MLWorkspaceName="aml-iotrains"; fi

# Install/Update CLI extensions
az extension add --upgrade --yes --name connectedk8s
az extension add --upgrade --yes --name k8s-extension
az extension add --upgrade --yes --name customlocation
az extension add --upgrade --yes --name appservice-kube
az extension add --upgrade --yes --name k8s-configuration
az extension add --upgrade --yes --name arcdata
az extension add --upgrade --yes --name ml

# Activate providers
providers=(Kubernetes KubernetesConfiguration ExtendedLocation Web AzureArcData)
for p in ${providers[@]}; do
  echo "Activating provider: Microsoft.$p";
  az provider register --namespace Microsoft.${p}
done

for p in ${providers[@]}; do
  echo ""
  echo "Testing provider: Microsoft.$p";
  echo "Test if Microsoft.$p provider is Registered."
  test=$(az provider show -n Microsoft.$p -o table | tail -n1 2>&1)
  while ( echo $test | grep -q "Registering" ); do \
    echo "Provider is server is still registering..."; \
    sleep 5; \
    test=$(az provider show -n Microsoft.$p -o table | tail -n1 2>&1); \
  done
  echo "Microsoft.Kuber$pnetes provider is Registered."
done

# Create Resource Group if not exist
echo "Create Resource Group..."
az group create --name $ResourceGroup --location $Location


# Create Log Analytics Workspace
echo "Create Log Analytics Workspace..."
az monitor log-analytics workspace create \
  --resource-group $ResourceGroup \
  --workspace-name $LogAnalyticsName \
  --location $Location

LogAnalyticsWorkspaceId=$(az monitor log-analytics workspace show \
    --resource-group $ResourceGroup \
    --workspace-name $LogAnalyticsName \
    --query customerId \
    --output tsv)
LogAnalyticsWorkspaceResourceId=$(az monitor log-analytics workspace show \
    --resource-group $ResourceGroup \
    --workspace-name $LogAnalyticsName \
    --query id \
    --output tsv)
LogAnalyticsWorkspaceIdEnc=$(printf %s $LogAnalyticsWorkspaceId | base64 -w0)
LogAnalyticsKey=$(az monitor log-analytics workspace get-shared-keys \
    --resource-group $ResourceGroup \
    --workspace-name $LogAnalyticsName \
    --query primarySharedKey \
    --output tsv)
LogAnalyticsKeyEnc=$(printf %s $LogAnalyticsKey | base64 -w0)


# Connect K8s with Arc
echo "Connect Cluster..."
az connectedk8s connect \
  --name $ClusterName \
  --resource-group $ResourceGroup

# Activate monitoring to the Log Analytics
az k8s-extension create \
  --name azuremonitor-containers \
  --cluster-name $ClusterName \
  --resource-group $ResourceGroup \
  --cluster-type connectedClusters \
  --extension-type Microsoft.AzureMonitor.Containers \
  --configuration-settings logAnalyticsWorkspaceResourceID="${LogAnalyticsWorkspaceResourceId}" \
  --configuration-settings omsagent.resources.daemonset.limits.cpu="150m" \
  --configuration-settings omsagent.resources.daemonset.limits.memory="600Mi" \
  --configuration-settings omsagent.resources.daemonset.requests.memory="300Mi" \
  --configuration-settings omsagent.resources.deployment.limits.cpu="1" \
  --configuration-settings omsagent.resources.deployment.limits.memory="750Mi"

# Deploy AppService extension
echo "Deploy AppService extension..."
az k8s-extension create \
    --resource-group $ResourceGroup \
    --name $AppExtName \
    --cluster-type connectedClusters \
    --cluster-name $ClusterName \
    --extension-type 'Microsoft.Web.Appservice' \
    --release-train stable \
    --auto-upgrade-minor-version true \
    --scope cluster \
    --release-namespace $AppExtNamespace \
    --configuration-settings "Microsoft.CustomLocation.ServiceAccount=default" \
    --configuration-settings "appsNamespace=${AppExtNamespace}" \
    --configuration-settings "clusterName=${AppEnvironmentName}" \
    --configuration-settings "keda.enabled=true" \
    --configuration-settings "buildService.storageClassName=${StorageClass}" \
    --configuration-settings "buildService.storageAccessMode=ReadWriteOnce" \
    --configuration-settings "customConfigMap=${AppExtNamespace}/kube-environment-config" \
    --configuration-settings "logProcessor.appLogs.destination=log-analytics" \
    --configuration-protected-settings "logProcessor.appLogs.logAnalyticsConfig.customerId=${LogAnalyticsWorkspaceIdEnc}" \
    --configuration-protected-settings "logProcessor.appLogs.logAnalyticsConfig.sharedKey=${LogAnalyticsKeyEnc}"

ExtensionId=$(az k8s-extension show \
    --cluster-type connectedClusters \
    --cluster-name $ClusterName \
    --resource-group $ResourceGroup \
    --name $AppExtName \
    --query id \
    --output tsv)
    
az resource wait --ids $ExtensionId --custom "properties.installState!='Pending'" --api-version "2020-07-01-preview"

# Create custom location for App Service
echo "Create custom location for App Service..."
ConnectedClusterId=$(az connectedk8s show --resource-group $ResourceGroup --name $ClusterName --query id --output tsv)

az customlocation create \
    --resource-group $ResourceGroup \
    --name $AppCustomLocationName \
    --host-resource-id $ConnectedClusterId \
    --namespace $AppExtNamespace \
    --cluster-extension-ids $ExtensionId

az customlocation show --resource-group $ResourceGroup --name $AppCustomLocationName

CustomLocationId=$(az customlocation show \
    --resource-group $ResourceGroup \
    --name $AppCustomLocationName \
    --query id \
    --output tsv)

# Create App Service plan
echo "# Create App Service plan..."

az appservice kube create \
    --resource-group $ResourceGroup \
    --name $AppEnvironmentName \
    --custom-location $CustomLocationId

# Create Azure Container Registry
az acr create \
    --resource-group $ResourceGroup \
    --name $ACRName \
    --sku Basic

# Deploy Machine Learning extension
az k8s-extension create \
  --name $AMLExtName \
  --cluster-name $ClusterName \
  --resource-group $ResourceGroup \
  --extension-type Microsoft.AzureML.Kubernetes \
  --config enableTraining=True \
           enableInference=True \
           inferenceRouterServiceType=LoadBalancer \
           allowInsecureConnections=True \
           inferenceLoadBalancerHA=False \
  --cluster-type connectedClusters  \
  --scope cluster


# Create an Azure ML workspace
az ml workspace create \
  --resource-group $ResourceGroup \
  --name $MLWorkspaceName

# Create Managed Identity for Arc-K8s
az identity create \
  --name $ArcMLExtIdentityName \
  --resource-group $ResourceGroup

AMLExtIdentityID=$(az identity show \
    --name  $ArcMLExtIdentityName \
    --resource-group $ResourceGroup \
    --query id \
    --output tsv)

# Attach Arc-K8s to ML workspace

ArcK8sID=$(az connectedk8s show \
    --name $ClusterName \
    --resource-group $ResourceGroup \
    --query id \
    --output tsv)


az ml compute attach \
  --resource-group $ResourceGroup \
  --workspace-name $MLWorkspaceName \
  --type Kubernetes \
  --name amlarc-compute \
  --resource-id $ArcK8sID \
  --identity-type UserAssigned \
  --user-assigned-identities $AMLExtIdentityID

# az logout
