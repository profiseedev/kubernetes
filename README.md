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

# Debug

## Uninstall profisee and reinstall
				
	helm repo add profisee https://profisee.github.io/kubernetes
	helm uninstall profiseeplatform2020r1
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
	
## Upgrade fro mone version to another

Create a file named UpdateProfisee.yaml (any name is fine as long as use that file name in the patch statement) that has this content:

	spec:
	  template:
	    spec:
	      containers:
	      - name: profisee
		image: profisee.azurecr.io/profisee2020r2:0

Upload to cloud shell drive
	
	Launch Cloud Shell from the top navigation of the Azure portal.
	
	Click upload/download, then upload and chose the file you just created 

Connect to aks cluster

	az aks get-credentials --resource-group MyResourceGroup --name MyAKSCluster --overwrite-existing

Patch it

	kubectl patch statefulset profisee --patch $(Get-Content UpdateProfisee.yaml -Raw)

