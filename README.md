# Profisee development - Deploy platform on to AKS

#### 'Lighting' Deploy Profisee platform (https via Lets ecrypt and generated dns and new sql and storage)....

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fprofiseedev%2Fkubernetes%2Fmaster%2FAzure-ARM-LE%2Fazuredeploynew.json)

#### 'Quick' Deploy Profisee platform (https via Lets ecrypt and generated dns)....

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fprofiseedev%2Fkubernetes%2Fmaster%2FAzure-ARM-LE%2Fazuredeploy.json)

#### 'Advanced' Deploy Profisee platform (latest development version - pushing to prod)....

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fprofiseedev%2Fkubernetes%2Fmaster%2FAzure-ARM%2Fazuredeploy.json)
<a href="http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2Fprofiseedev%2Fkubernetes%2Fmaster%2FAzure-ARM%2Fazuredeploy.json" target="_blank">
  <img src="http://armviz.io/visualizebutton.png"/>
</a>

# Prerequisites:

1.  Be a profisee employee or very friendly

# Verify:

1.  Open up cloud shell
    
    Launch Cloud Shell from the top navigation of the Azure portal.
    
    ![CloudShell](https://docs.microsoft.com/en-us/azure/cloud-shell/media/quickstart/shell-icon.png)
  
2.  Configure kubectl

        az aks get-credentials --resource-group MyResourceGroup --name MyAKSCluster --overwrite-existing
    
3.  The initial deploy will have to download the container which takes about 10 minutes.  Verify its finished downloading the container:

		kubectl describe pod profisee-0 #check status and wait for "Pulling" to finish

4.  Container can be accessed with the following command:
    
        kubectl exec -it profisee-0 powershell

5.  System logs can be accessed with the following command:

		#Configuration log
		Get-Content C:\Profisee\Configuration\LogFiles\SystemLog.log
		#Authentication service log
		Get-Content C:\Profisee\Services\Auth\LogFiles\SystemLog.log
		#WebPortal Log
		Get-Content C:\Profisee\WebPortal\LogFiles\SystemLog.log
		#Gateway log
		Get-Content C:\Profisee\Web\LogFiles\SystemLog.log

6.  Goto Profisee Platform web portal
	- http(s)://app.company.com/profisee
	
# Debug

## Uninstall nginx and reinstall
				
	#install nginx
	helm repo add stable https://kubernetes-charts.storage.googleapis.com/;
	#get profisee nginx settings
	curl -fsSL -o nginxSettings.yaml https://raw.githubusercontent.com/profisee/kubernetes/master/Azure-ARM/nginxSettings.yaml;
	helm uninstall nginx
	helm install nginx stable/nginx-ingress --values nginxSettings.yaml --set controller.service.loadBalancerIP=$publicInIP;
	
## Uninstall profisee and reinstall
				
	helm repo add profisee https://profisee.github.io/kubernetes
	helm uninstall profiseeplatform2020r1
	#get settings.yaml from the secret its stored in
	kubectl get secret profisee-settings -o jsonpath="{.data.Settings\.yaml}" | base64 --decode > Settings.yaml
	helm install profiseeplatform2020r1 profisee/profisee-platform --values Settings.yaml
	
## Connect to container and look at log

	kubectl exec -it profisee-0 powershell
	Get-Content C:\Profisee\Configuration\LogFiles\SystemLog.log

## Check sql connection from container

	$connectionString = 'Data Source={0};database={1};User ID={2};Password={3}' -f $env:ProfiseeSqlServer,$env:ProfiseeSqlDatabase,$env:ProfiseeSqlUserName,$env:ProfiseeSqlPassword
	$sqlConnection = New-Object System.Data.SqlClient.SqlConnection $connectionString
	$sqlConnection.Open()
	$sqlConnection.Close()

## Check connection to fileshare

	#map drive to X
	$pass=$env:ProfiseeAttachmentRepositoryUserPassword|ConvertTo-SecureString -AsPlainText -Force
	$azureCredential = New-Object System.Management.Automation.PsCredential($env:ProfiseeAttachmentRepositoryUserName,$pass)
	New-PSDrive -Name "X" -PSProvider "FileSystem" -Root $env:ProfiseeAttachmentRepositoryLocation -Credential $azureCredential -Persist;
	#remove mapped drive
	Remove-PSDrive X
		
## Copying files to/from container

	#copy file to container
	kubectl cp appsettings.json profisee-0:profisee/services/auth/appsettings.json

	#copy file from container
	kubectl cp profisee-0:profisee/services/auth/appsettings.json appsettings.json
	
## "Edit" a value (logging) in web.config

	((Get-Content -path C:\profisee\services\auth\appsettings.json -Raw) -replace 'Warning','Debug') | Set-Content -Path C:\profisee\services\auth\appsettings.json

	
## Upgrade from one version to another

Create a file named UpdateProfisee.yaml (any name is fine as long as use that file name in the patch statement) that has this content:

	spec:
	  template:
	    spec:
	      containers:
	      - name: profisee
		image: profisee.azurecr.io/profisee2020r2:preview

Upload to cloud shell drive
	
	Launch Cloud Shell from the top navigation of the Azure portal.
	Click upload/download, then upload and chose the file you just created 	

Connect to aks cluster
	
	az aks get-credentials --resource-group MyResourceGroup --name MyAKSCluster --overwrite-existing

Patch it

	kubectl patch statefulset profisee --patch $(Get-Content UpdateProfisee.yaml -Raw)

# Debug with Lens

## Install Lens (Kubernetes IDE)

Main website https://k8slens.dev

Install the latest https://github.com/lensapp/lens/releases/latest

## Add AKS cluster to Lens

	Go to Azure portal, open cloud shell

	Run this to "configure" kunectl
	az aks get-credentials --resource-group MyResourceGroup --name MyAKSCluster --overwrite-existing
	
	Get contents of kube.config
	run kubectl config view --minify --raw
	copy all the out put of that command (select with mouse, right click copy)
	
	Go to Lens
	Click big plus (+) to add a cluster
	Click paste as text
	Goto select contect dropdown and choose the cluster
	Click outside the dropdown area
	Click "Add Cluster(s)"
	Wait for it to connect and now Lens is connected to that aks cluster.
	
## Connect to pod (container)

	In Lens, choose workloads, then pods
	Click on pod - profisee-(x)
	Click on the "Pod Shell" left icon in top blue nav bar.  This will "connect" you to the container
	Now in the terminal window (bottom), you are "connected" to the pod (container)

## Replace license with Lens

	In Lens, choose workloads, then Configuration, then secrets
	Click on profisee-files
	Paste your new license string supplied byb Profisee Support in textbox under profisee.plic
	Click save.
	Your license has been updated.
	You have to detroy the pod and have it recreate itself for it to take affect.
