# Introduction
This guide walks you through on different aspects of the solution. First the infrasturcture setup including the K8s cluster and the Azure environement setup. Then the Azure ML environment and the model creation. Finally the execution part wich includes the camera setup with Raspberry and/or an ESP32-CAM and deploying the scoring script with the minimal webpage.

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
In this section we will train our AI model and prepare for remote deployment.

Go to the Azure portal, find your Azure ML workspace and login into the Studio

## Create pictures
Create pictures from the object what you would like to detect. In our case these are the Lego figures. More pictures will result better model. I suggest to have pictures with 1000 Lego figures. One pictures can contain multiple figures in the same time.

## Create DataSet
- Click on **Data** on the left menu
- You shall arrive to the **Data assets** page. Click on the **Create** button
  - Give a name like **Lego_figures**
  - Select **Type** as **Dataset types (from Azure ML v1 APIs) / File**. It is at the most bottom. If you select wrong type then it won't be visible in the Labeling.
  - On the **Data source** page select **From local files**
  - On the **Storage type** keep the recommended **Azure Blob Storage** and the selected **workspaceblobstore**
  - On the **Folder selection** page click on the **Upload** button and select the folder where you stored your pictures
  - Wait until the upload is done
  - Next-Next-Finish

## Data Labeling
Once we have a nice dataset then we need to label/annotate it.

- Click on the **Data Labeling** at the bottom of the left menu
- Click on Create
- Give a name like **Minifigures**
- **Media type** remains as **Image**
- **Labeling task type** shall be **Object Identification (Bounding Box)** ... **Next**
- Skip **Add workforce** ... **Next**
- On the **Select or create data** select the previously created **Lego_figures** dataset. (Put a checkmark to front of the name.)
- Skip the **Incremental refresh** ... **Next**
- At the **Label categories** add a label like **Minifigure**
- Skip the **Label instructions** ... **Next**
- Skip the **Quality control** ... **Next**
- Disable the **Enable ML assisted labeling** (it works only with huge datasets) ... **Create project**

Once the project is ready then select (activate) your project.

- Click on your project like **Minifigures**
- Click on the **Label data** button at the middle top. This opens an editor and loads one of our picture.
- Draw a box around all the minifigures. Pay attention to include only the minifigure with his/her accessories.
- If you marked all minifigures then click on the **Submit** button.
- Repeat the labelling with all the pictures.

When finished the long droid work and you labelled all your images then you can review and approve them.

- Go to your labelling project's page.
- Go to the the **Data** tab
- Select **Review labels**
- You can scroll through and **Approve** your pictures

Export your work so we can start the training based on that information.
- Go to your labelling project's page.
- Click on the **Export**
- Select **Azure ML Dataset** as Export format
- Click on **Submit**

Exporting takes couple of seconds.

## Create a compute cluster
A compute cluster is needed to train our model. You can create a Virtual Machine Scale Set which will automatically scale based on the required amount of jobs.

- At **Virtual machine tier** you can select **Low priority**. This is supercheap but it isn't guaranteed that you get the resource.
- Select **GPU** as **Virtual machine type**
- Find the smallest and cheapest VM. At the time of writing it is **Standard_NC4as_T4_v3**
- Give a name at **Compute name**
- Leave the minimum at 0 and the maximum at 1
- Click on **Create**

## (alternative) Create compute instance
As an alternative of the Compute cluster you can create a single instance. It has benefit if we use it for inferencing or troubleshooting which is NOT the case now henve I suggest to use the Compute cluster but I leave this description here if you wish to go with a single node.

- Click on the **Compute** button at the bottom of the left menu
- Stay on the **Compute instances** tab and click on the **+New** button
- Give a fance name to your Compute or leave the auto generated.
- Select **GPU** as **Virtual machine type**
- Find the smallest and cheapest VM. At the time of writing it is **Standard_NC4as_T4_v3**
- On the **Scheduling** page, decrease the autoshutdown to 20 minutes
- Leave everything on the **Security** page
- Leave everything on the **Applications** page
- Skip the **Tags** page
- Click on **Create**

Creation will take several minutes.

## Training with Automated ML
Now we prepared our data and we also have some compute capacity. It is the time to train the model. Training a model is a little bit a trial and error method and takes several iterations. Luckily the Auto ML function will do this for us.

- Go to the **Automated ML** site on the left menu
- Click on the **+New Automated ML job** button
- Our just exported dataset shall appear hear. Select the **Dataset**. (Mine is Minifigures_20230912_133406)
- Click **Next**
- For the **Target column** select **label (List)**
- Select your **Compute cluster** and click **Next**
- **yolov5** is automatically selected but we need to fine-tune a bit
  - Click on the **+Add new hyperparameter**
    - Name: **learning_rate**
    - Distribution: **Uniform**
    - Min: **0.0001**
    - Max: **0.01**
    - Click on **Save**
  - Click on the **+Add new hyperparameter** 
    - Name: **model_size**
    - Distribution: **Choice**
    - Values: **small, medium**
    - Click on **Save**
- With this the yolo model is prepared but we can try out other models like ResNet or Faster-RCNN. Let's add several variants to the list and leave it to the AutoML to test them.
- Click on **+Add new model algorithm** and select **fasterrcnn_resnet34_fpn**
  - We also can fine-tune with the hyperparameters so let's do it.
  - Click on the **+Add new hyperparameter**
    - Name: **learning_rate**
    - Distribution: **Uniform**
    - Min: **0.0001**
    - Max: **0.001**
    - Click on **Save*
  - Click on the **+Add new hyperparameter** 
    - Name: **optimizer**
    - Distribution: **Choice**
    - Values: **sgd, adam, adamw**
    - Click on **Save**
  - Click on the **+Add new hyperparameter** 
    - Name: **min_size**
    - Distribution: **Choice**
    - Values: **600, 800**
    - Click on **Save**
- Click on **+Add new model algorithm** and select **fasterrcnn_resnet50_fpn** (notice the number)
  - Repeat the same hyperparameter settings like with the fasterrcnn_resnet34_fpn
- Leave the **Sampling** as **Random**
- Change the **Iterations** to **10** (or any value what you like)
- Select **Bandit** as **Early stopping**
  - **Slack factor** is **0.2**
  - **Evaluation interval** is **2**
  - **Delay evaluation** is **6**
- Leave the **Concurrent iterations** empty and click on **Next**
- Leave the **Validation type** as **Auto**
- Click on **Finish**

Note that the hyperparameters' configuration are copied from the Azure's tutorial from here: https://learn.microsoft.com/en-us/azure/machine-learning/tutorial-auto-train-image-models?view=azureml-api-2&tabs=cli#job-limits

Also note that each model has its own parameter set hence setting the "optimizer" to yolo doesn't make any effect.

Now our traing is on the way and it will take several hours. You can follow the training progress if you go to the **Child jobs** tab. You can also see the results in the **Models** tab. If you created a Compute cluster with higher max value than 1 then you will see parallel child jobs.

## Register model
- Go to the **Automated ML** site on the left menu
- Select the lastly created project
- Go to the **Models** tab
- Select on of the models which has high Mean average
- Click on **Deploy** and **Real-time deployment**
- Click on the **More options** at the bottom right
- Set **Compute type** as **Kubernetes**
- Select your cluster at the **Select Kubernetes cluster** drop-down list
- Click on **Next** until you reach the **Compute** tab
- Set the **Instance type** as **cudainstancetype**
- Set the **Instance count** as **1**
- **Next-Next-Create**

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
The ESP32-CAM program is based on the CameraWebServer example with the following tunings:
- The proper board type is selected at the beginning. Mine is AI thinker but your can be different.
- Fix IP address is configured to make it easier to find.
- Brownout detection is disabled so it will be more tolerant to powerbank's voltage fluctuation.

Setup:
- Download the files from [ESP32-CAM folder](https://github.com/szasza576/arc-iotrains/tree/main/ESP32-CAM)
- Update your WiFi credentials and IP address in the CameraWebServer.ino
- Compile and Upload with Arduino IDE (or your favorit Arduino tool)

## Train with Raspberry Pi
Install Raspbian and setup WiFi.

### WiFi driver setup for Realtek stick (optional, HW specific)
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

If you use a camera which is not v4l2 compatible then you can use another like ```fswebcam```, ```streamer``` or ```ffmpeg```. I have to leave this setup to you as this is HW specific. Note that, the mentioned programs do the jpeg encoding by CPU so it might slow down the whole process. For me a Raspberry B+ (yes, 1st gen) can take pictures in 0.5 second with v4l2 but it takes 3-5 seconds with the mentioned programs.

You might need to finetune the ```pixelformat``` parameter in the script. The following commands might help to figure out the supported formats by your camera:
```bash
v4l2-ctl --list-devices
v4l2-ctl --list-formats-ext
```

## Detector

Build image
```bash
az acr build -r $ACRName https://github.com/szasza576/arc-iotrains.git#main:detector/dockerimage -f Dockerfile --platform linux -t detector:latest
```

Deploy the basic Kubernetes components:
```bash
kubectl apply -f https://raw.githubusercontent.com/szasza576/arc-iotrains/main/detector/k8s-manifests/namespace.yaml
kubectl apply -f https://raw.githubusercontent.com/szasza576/arc-iotrains/main/detector/k8s-manifests/html-configmap.yaml
kubectl apply -f https://raw.githubusercontent.com/szasza576/arc-iotrains/main/detector/k8s-manifests/marker-service.yaml
kubectl apply -f https://raw.githubusercontent.com/szasza576/arc-iotrains/main/detector/k8s-manifests/pv-source.yaml
kubectl apply -f https://raw.githubusercontent.com/szasza576/arc-iotrains/main/detector/k8s-manifests/pvc-archive.yaml
kubectl apply -f https://raw.githubusercontent.com/szasza576/arc-iotrains/main/detector/k8s-manifests/pvc-source.yaml
```

OPTIONAL Note that, you shall create this ONLY with the ESP32-CAM. If you use ESP32-CAM then specify its IP address in a ConfigMap.
```bash
kubectl create configmap espcam-ip -n minifigures \
--from-literal espcamip="192.168.0.131"
```

Create a secret with your ML endpoint:
```bash
AmlEndpoint=$(az ml online-endpoint list --resource-group $ResourceGroup --workspace-name $MLWorkspaceName --query [0].name --output tsv)
AmlURI=$(az ml online-endpoint show --name $AmlEndpoint --resource-group $ResourceGroup --workspace-name $MLWorkspaceName --query scoring_uri --output tsv)
AmlKey=$(az ml online-endpoint get-credentials --name $AmlEndpoint --resource-group $ResourceGroup --workspace-name $MLWorkspaceName --query primaryKey --output tsv)

kubectl create secret generic inference-secret -n minifigures \
 --from-literal scoreendpoint=$AmlURI \
 --from-literal scorekey=$AmlKey \
 --dry-run=client \
 -o yaml | \
 kubectl apply -f -
```

Create pull secret for ACR
```bash
ACRUser=$(az acr credential show -n $ACRName -g $ResourceGroup --query username --output tsv)
ACRPassword=$(az acr credential show -n $ACRName -g $ResourceGroup --query 'passwords[0].value' --output tsv)

kubectl create secret docker-registry acr-secret -n minifigures \
  --docker-server="${ACRName}.azurecr.io" \
  --docker-username=$ACRUser \
  --docker-password=$ACRPassword
```

Download the Marker App's manifest file and update the Registry inside it. Then deploy the Marker App:
```bash
wget https://raw.githubusercontent.com/szasza576/arc-iotrains/main/detector/k8s-manifests/marker-deployment.yaml
sed -i s/"<YOURACR>"/$ACRName/g marker-deployment.yaml
kubectl apply -f marker-deployment.yaml
rm marker-deployment.yaml
```

## Webpage credits
The JavaScript parts of the webpage was built by my friend [Norbi](https://github.com/ncseffai).

## Testing
Finally if everything was brought together then the containers are running.

Either login in to the Raspberry and start the image taker script:
```bash
./pics.sh
```

Or either power on the ESP32 controller.

The marker app starts grabbing the new images and send them to the ML endpoint. You can see the results on the webpage.
Get the IP address of the webserver:
```bash
kubectl get svc -n minifigures maker-svc
```

Enter the IP into your browser with http:// prefix (not https):
```
http://<MAKER'S IP ADDRESS>

#Example:
http://192.168.0.141
```

## Troubleshooting
If you redeploy the AI model and you create a new endpoint then you need to update the credentials as well so you need to re-execute these commands:
```bash
AmlEndpoint=$(az ml online-endpoint list --resource-group $ResourceGroup --workspace-name $MLWorkspaceName --query [0].name --output tsv)
AmlURI=$(az ml online-endpoint show --name $AmlEndpoint --resource-group $ResourceGroup --workspace-name $MLWorkspaceName --query scoring_uri --output tsv)
AmlKey=$(az ml online-endpoint get-credentials --name $AmlEndpoint --resource-group $ResourceGroup --workspace-name $MLWorkspaceName --query primaryKey --output tsv)

kubectl create secret generic inference-secret -n minifigures \
 --from-literal scoreendpoint=$AmlURI \
 --from-literal scorekey=$AmlKey \
 --dry-run=client \
 -o yaml | \
 kubectl apply -f -
```

...and you need to delete the running pod to take the new configuration:
```bash
kubectl delete pod -n minifigures -l app=marker
```