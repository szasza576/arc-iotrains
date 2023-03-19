# Introduction

# Infra setup

## Node install
- Install Ubuntu 22.04 Server
  - VM config minimum requirements:
    - vCPU: 4
    - vRAM: 8GB (don't use dynamic allocation)
    - vDisk: 80GB
  - Network:
    - Bridged network
    - IP: 192.168.0.128/24 (change according your setup)
    - Gateway: 192.168.0.1/24
    - DNS: 192.168.0.1,8.8.8.8

## Kubernetes node setup
You can use your parameters with setting up these variables. Otherwise the script goes with its own default.
  ```
  K8sVersion="1.25.8-00"
  PodCIDR="172.16.0.0/16"
  ServiceCDR="172.17.0.0/16"
  IngressRange="192.168.0.130-192.168.0.140"
  MasterIP="192.168.0.128"
  MasterName="arc-kube-master"
  NFSCIDR="192.168.0.128/25"
  ```

Run the [deployer script](/infra-setup/kube-node-setup.sh)

## Azure CLI install
One PC shall reach the K8s API and have the Azure CLI installed. Either install the Azure CLI to the master node or either copy the kubeconfig file to your PC.

Azure CLI installation methods: https://learn.microsoft.com/en-us/cli/azure/install-azure-cli

For Ubuntu:
```bash
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```

Once the installation is ready then login into Azure
```bash
az login
az account set --subscription <your-subscription-id>
```

## Azure environment setup
The following script will create the following resources:
- Resource Group
- Log Analytics Workspace
- Arc connected Kubernetes and attach the K8s cluster
- AppService extension
- Machine Learning Workspace
- ML extension
- Attach the K8s cluster to the ML workspace as Compute

Optionally you can influence the deployment with changing the following variables (except the Resource Group name and Location it is not recommended):
```
ResourceGroup="Arc-IoTrains"
Location="westeurope"
LogAnalyticsName="iotrains-logs"
ClusterName="iotrains-k8s"
AppExtName="appservice-ext"
AppExtNamespace="iotrains-apps"
AppEnvironmentName="iotrains-appservices"
AppCustomLocationName="iotrains-app-site"
StorageClass="default"
ACRName="iotrainsacr"
AMLExtName="iotrains-ml"
AMLIdentityName="iotrains-ml-identity"
ArcMLExtIdentityName="iotrains-arc-identity"
MLWorkspaceName="aml-iotrains"
```

Once the variable are configured then

Run the [azure setup script](/infra-setup/azure-setup.sh)

# Azure ML
Login into the Studio

## Create DataSet
- Click on **Data** on the left menu
- You shall arrive to the **Data assets** page. Click on the **Create** button
  - Give a name like **Lego_Validator_Set**
  - Select **Type** as **Folder (uri_folder)**
  - On the **Data source** page select **From local files**
  - On the **Storage type** keep the recommended **Azure Blob Storage** and the selected **workspaceblobstore**
  - On the **Folder selection** page click on the **Upload** button and select the folder where you stored your pictures
  - Next-Next-Finish

## Data Labeling
Once we have a nice dataset then we need to label/annotate it.

- Click on the **Data Labeling** at the bottom of the left menu
- Click on Create
- Give a name like **Minifigures_validator**
- **Media type** remains as **Image**
- **Labeling task type** shall be **Object Identification (Bounding Box)** ... **Next**
- Skip **Add workforce** ... **Next**
- On the **Select or create data** click on the **Create** button
  - Give a name like Lego_valid ... **Next**
  - Select **From Azure storage** as **Data source** ... **Next**
  - Select the previously used **workspaceblobstore**  ... **Next**
  - Browse to the folder which holds the pictures. Stay at the folder level and select it.  ... **Next**  ... **Create**
- Select the freshly created Data asset  ... **Next**
- Skip the Incremental refresh ... **Next**
- At the **Label categories** add a label like **Minifigure**
- Skip the **Label instructions** ... **Next**
- Skip the **Quality control** ... **Next**
- Disable the **Enable ML assisted labling** (it works only with huge datasets) ... **Create project**








## Model training

## Azure-Arc connectivity


# Execution

## Train with ESP32-CAM

## Train with Raspberry Pi

## Detector

## Webpage

