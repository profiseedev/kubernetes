# Profisee development - Deploy Profisee platform on to AKS

#### Deploy Profisee platform (latest development version - pushing to prod)....

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fprofiseedev%2Fkubernetes%2Fmaster%2FAzure-ARM%2Fazuredeploy.json)
<a href="http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2Fprofiseedev%2Fkubernetes%2Fmaster%2FAzure-ARM%2Fazuredeploy.json" target="_blank">
  <img src="http://armviz.io/visualizebutton.png"/>
</a>


#### Deploy Profisee platform (https via Lets ecrypt and generated dns)....

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fprofiseedev%2Fkubernetes%2Fmaster%2FAzure-ARM-LE%2Fazuredeploy.json)

#### Deploy Profisee platform (https via Lets ecrypt and generated dns and new sql and storage)....

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fprofiseedev%2Fkubernetes%2Fmaster%2FAzure-ARM-LE%2Fazuredeploynew.json)


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

## Uninstall profisee and reinstall
				
	helm repo add profisee https://profisee.github.io/kubernetes
	helm uninstall profiseeplatform2020r1
	#get settings.yaml fro mteh secret its stored in
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

	(Get-Content -path C:\profisee\services\auth\web.config -Raw) -replace 'stdoutLogEnabled="false"','stdoutLogEnabled="true"'
	
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

