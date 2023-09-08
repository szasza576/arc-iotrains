# Introduction

# Infra setup
## Kubernetes node setup
Follow this guide to bring up your base infrastructure: https://github.com/szasza576/kube-installation

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

## Preparation on the kube-master node
Create a folder for the pictures what the toy train will generate and upload.
Run these commands on the kube-master (which acts as the NFS share):

```bash
mkdir -p /mnt/k8s-pv-data/train-pics
sudo chmod 777 /mnt/k8s-pv-data/train-pics
sudo chown nobody:nogroup /mnt/k8s-pv-data/train-pics
```

## Train with ESP32-CAM

## Train with Raspberry Pi
Install Raspbian and setup WiFi.

### WiFi driver setup for Realtek stick
I have a Realtek WiFi stick which needs a special driver to be compiled. This is HW specific hence you might not need this step.
```bash
sudo apt-get install -y git dkms raspberrypi-kernel-headers bc

git clone https://github.com/cilynx/rtl88x2bu.git
cd rtl88x2bu

sed -i 's/I386_PC = y/I386_PC = n/' Makefile
sed -i 's/ARM_RPI = n/ARM_RPI = y/' Makefile

VER=$(sed -n 's/\PACKAGE_VERSION="\(.*\)"/\1/p' dkms.conf)
sudo rsync -rvhP ./ /usr/src/rtl88x2bu-${VER}
sudo dkms add -m rtl88x2bu -v ${VER}
sudo dkms build -m rtl88x2bu -v ${VER}
sudo dkms install -m rtl88x2bu -v ${VER}
sudo modprobe 88x2bu
```

### Network configuration
Once the WiFi driver is ready then setup the WiFi SSID and WPA key here:
```bash
sudo raspi-config
```

Configure a static IP address which is inside the "NFSCIDR" variable from the other guide.
For example the 192.168.0.130 is a good pick.

To setup a static IP address run this command and then restart the node. Don't forget this modifies the IP address so update your SSH client too.
```bash
sudo tee -a /etc/dhcpcd.conf<<EOF
interface wlan0
static ip_address=192.168.0.130/24
static routers=192.168.0.1
static domain_name_servers=192.168.0.1,8.8.8.8
EOF
```

Mount the NFS share from the kube-master node so we can save the pictures directly to the kube-master server.
```bash
sudo apt install -y nfs-common

echo "192.168.0.128:/mnt/k8s-pv-data/train-pics /mnt/pics nfs defaults 0 0" | sudo tee -a /etc/fstab
```

Finally reboot the Raspberry to apply all settings.
```bash
sudo reboot
```


### Picture taker
Download the picture capture script which creates pictures as fast it can.
```bash
wget https://raw.githubusercontent.com/szasza576/arc-iotrains/main/pics-capture/pics.sh

chmod +x pics.sh
```

If you use a camera which is not v4l2 compatible then you can use another like ```fswebcam```, ```streamer``` or ```ffmpeg```. I have to leave this setup to you as this is HW specific. Note that, the mentioned programs do the jpeg encoding by CPU so it might slow down the whole process. For me a Raspberry B+ (yes, 1st gen) can take pictures in 0.5 second.

You might need to finetune the ```pixelformat``` parameter in the script. The following commands might help to figure out the supported formats by your camera:
```bash
v4l2-ctl --list-devices
v4l2-ctl --list-formats-ext
```

## Detector

Build image
az acr build -r $ACRName https://github.com/szasza576/arc-iotrains.git#main:detector/dockerimage -f Dockerfile --platform linux -t detector:latest

ENV scoreendpoint=http://192.168.0.143/api/v1/endpoint/minifigures/score
ENV scorekey=ETPVefMh7pMLIPo4u6j4eyZkBIjXp8gp


kubectl apply -f https://raw.githubusercontent.com/szasza576/arc-iotrains/main/detector/k8s-manifests/namespace.yaml
kubectl apply -f https://raw.githubusercontent.com/szasza576/arc-iotrains/main/detector/k8s-manifests/html-configmap.yaml
kubectl apply -f https://raw.githubusercontent.com/szasza576/arc-iotrains/main/detector/k8s-manifests/marker-service.yaml
kubectl apply -f https://raw.githubusercontent.com/szasza576/arc-iotrains/main/detector/k8s-manifests/pv-source.yaml
kubectl apply -f https://raw.githubusercontent.com/szasza576/arc-iotrains/main/detector/k8s-manifests/pvc-archive.yaml
kubectl apply -f https://raw.githubusercontent.com/szasza576/arc-iotrains/main/detector/k8s-manifests/pvc-source.yaml

wget https://raw.githubusercontent.com/szasza576/arc-iotrains/main/detector/k8s-manifests/marker-deployment.yaml
sed -i s/"<YOURACR>"/$ACRName/g marker-deployment.yaml
kubectl apply -f marker-deployment.yaml
rm marker-deployment.yaml


wget https://raw.githubusercontent.com/szasza576/arc-iotrains/main/detector/k8s-manifests/marker-secret.yaml


https://raw.githubusercontent.com/szasza576/arc-iotrains/main/detector/k8s-manifests/marker-deployment.yaml
sed -i s/"<youracr>"/$ACRName/g boy.ymlsed -i s/"<youracr>"/$ACRName/g boy.yml


DOCKERPULL SECRET!!!!!!!!!!!!!!!!!
ACR ADMIN MODE


iotrainsacr
YGWPXwxqvRvMiRtnv7u2mBYALRucDujUCyIIIeFwmQ+ACRAaVJYE


kubectl create secret docker-registry acr-secret --docker-server=iotrainsacr.azurecr.io --docker-username=iotrainsacr --docker-password=YGWPXwxqvRvMiRtnv7u2mBYALRucDujUCyIIIeFwmQ+ACRAaVJYE -n minifigures


## Webpage

https://github.com/ncseffai