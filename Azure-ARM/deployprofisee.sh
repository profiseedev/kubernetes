#!/bin/bash
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
logfile=log_$(date +%Y-%m-%d_%H-%M-%S).out
exec 1>$logfile 2>&1

echo $"Profisee deploymented started $(date +"%Y-%m-%d %T")";


FILE=./get_helm.sh
if [ -f "$FILE" ]; then
    echo $"Profisee deploymented exiting, already has been ran";
	exit 1;
fi

REPONAME="profiseeadmin"
REPOURL="https://raw.githubusercontent.com/$REPONAME/kubernetes/master";
HELMREPOURL="https://$REPONAME.github.io/kubernetes";
echo $"REPOURL is $REPOURL";
echo $"HELMREPOURL is $HELMREPOURL";

if [ -z "$RESOURCEGROUPNAME" ]; then
	RESOURCEGROUPNAME=$ResourceGroupName
fi

if [ -z "$SUBSCRIPTIONID" ]; then
	SUBSCRIPTIONID=$SubscriptionId
fi

printenv;

#az login --identity

#Get AKS credentials, this allows us to use kubectl commands, if needed.
az aks get-credentials --resource-group $RESOURCEGROUPNAME --name $CLUSTERNAME --overwrite-existing;

#Install dotnet core.
echo $"Installation of dotnet core started.";
curl -fsSL -o dotnet-install.sh https://dot.net/v1/dotnet-install.sh
#Set permisssions for installation script.
chmod 755 ./dotnet-install.sh
#Install dotnet.
./dotnet-install.sh -c Current
echo $"Installation of dotnet core finished.";

#Downloadind and extracting Proisee license reader.
echo $"Download and extraction of Profisee license reader started.";
curl -fsSL -o LicenseReader.tar.001 "$REPOURL/Utilities/LicenseReader/LicenseReader.tar.001"
curl -fsSL -o LicenseReader.tar.002 "$REPOURL/Utilities/LicenseReader/LicenseReader.tar.002"
curl -fsSL -o LicenseReader.tar.003 "$REPOURL/Utilities/LicenseReader/LicenseReader.tar.003"
curl -fsSL -o LicenseReader.tar.004 "$REPOURL/Utilities/LicenseReader/LicenseReader.tar.004"
cat LicenseReader.tar.* | tar xf -
rm LicenseReader.tar.001
rm LicenseReader.tar.002
rm LicenseReader.tar.003
rm LicenseReader.tar.004
echo $"Download and extraction of Profisee license reader finished.";

echo $"Clean Profisee license string of any unwanted characters such as linebreaks, spaces, etc...";
LICENSEDATA=$(echo $LICENSEDATA|tr -d '\n')

echo $"Search Profisee license for the fully qualified domain name value...";
EXTERNALDNSURLLICENSE=$(./LicenseReader "ExternalDnsUrl" $LICENSEDATA)

#Use FQDN that is in license, otherwise use the Azure generated FQDN.
#EXTERNALDNSURLLICENSE=$(<ExternalDnsUrl.txt)
if [ "$EXTERNALDNSURLLICENSE" = "" ]; then
	echo $"EXTERNALDNSURLLICENSE is empty"
else	
	echo $"EXTERNALDNSURLLICENSE is not empty"
	EXTERNALDNSURL=$EXTERNALDNSURLLICENSE
	EXTERNALDNSNAME=$(echo $EXTERNALDNSURL | sed 's~http[s]*://~~g')
	DNSHOSTNAME=$(echo "${EXTERNALDNSNAME%%.*}")	
fi
echo $"EXTERNALDNSURL is $EXTERNALDNSURL";
echo $"EXTERNALDNSNAME is $EXTERNALDNSNAME";
echo $"DNSHOSTNAME is $DNSHOSTNAME";

#If ACR credentials are passed in via legacy script, use those. Otherwise, pull ACR credentials from license.
if [ "$ACRUSER" = "" ]; then
	echo $"ACR credentials were not passed in, will use values from license."
	#ACRUSER=$(<ACRUserName.txt)
	#ACRUSERPASSWORD=$(<ACRUserPassword.txt)
	ACRUSER=$(./LicenseReader "ACRUserName" $LICENSEDATA)
    ACRUSERPASSWORD=$(./LicenseReader "ACRUserPassword" $LICENSEDATA)
else
	echo $"Using ACR credentials that were passed in."
fi
echo $"ACRUSER is $ACRUSER";
echo $"ACRUSERPASSWORD is $ACRUSERPASSWORD";

echo $"Finished parsing values from Profisee license.";

#Install Helm
echo $"Installation of Helm started.";
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3;
chmod 700 get_helm.sh;
./get_helm.sh;
echo $"Installation of Helm finished.";

#Install kubectl
echo $"Installation of kubectl started.";
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
echo $"Installation of kubectl finished.";

#Create profisee namespace in AKS cluster.
echo $"Creation of profisee namespace in cluster started.";
kubectl create namespace profisee
echo $"Creation of profisee namespace in cluster finished.";

#Download settings.yaml file from Profisee repo.
curl -fsSL -o Settings.yaml "$REPOURL/Azure-ARM/Settings.yaml";

#Installation of Key Vault Container Storage Interface (CSI) driver started.
if [ "$USEKEYVAULT" = "Yes" ]; then
	echo $"Installation of Key Vault Container Storage Interface (CSI) driver started."
	#Install the Secrets Store CSI driver and the Azure Key Vault provider for the driver
	helm repo add csi-secrets-store-provider-azure https://raw.githubusercontent.com/Azure/secrets-store-csi-driver-provider-azure/master/charts
	
	#https://github.com/Azure/secrets-store-csi-driver-provider-azure/releases/tag/0.0.16
	#The behavior changed so now you have to enable the secrets-store-csi-driver.syncSecret.enabled=true
	#We are not but if this is to run on a windows node, then you use this --set windows.enabled=true --set secrets-store-csi-driver.windows.enabled=true
	helm install --namespace profisee csi-secrets-store-provider-azure csi-secrets-store-provider-azure/csi-secrets-store-provider-azure --set secrets-store-csi-driver.syncSecret.enabled=true
	echo $"Installation of Key Vault Container Storage Interface (CSI) driver finished."
	
	#Install AAD pod identity into AKS.
	echo $"Installation of Key Vault Azure Active Directory Pod Identity driver started."
	helm repo add aad-pod-identity https://raw.githubusercontent.com/Azure/aad-pod-identity/master/charts
	helm install --namespace profisee pod-identity aad-pod-identity/aad-pod-identity
	echo $"Installation of Key Vault Azure Active Directory Pod Identity driver finished."

	#Assign AAD roles to the AKS AgentPool Managed Identity. The Pod identity communicates with the AgentPool MI, which in turn communicates with the Key Vault specific Managed Identity.
	echo $"AKS Managed Identity configuration for Key Vault access started."

	echo $"AKS AgentPool Managed Identity configuration for Key Vault access step 1 started."
	echo "Running az role assignment create --role "Managed Identity Operator" --assignee $KUBERNETESCLIENTID --scope /subscriptions/$SUBSCRIPTIONID/resourcegroups/$RESOURCEGROUPNAME"
	az role assignment create --role "Managed Identity Operator" --assignee $KUBERNETESCLIENTID --scope /subscriptions/$SUBSCRIPTIONID/resourcegroups/$RESOURCEGROUPNAME
	echo "Running az role assignment create --role "Managed Identity Operator" --assignee $KUBERNETESCLIENTID --scope /subscriptions/$SUBSCRIPTIONID/resourcegroups/$AKSINFRARESOURCEGROUPNAME"
	az role assignment create --role "Managed Identity Operator" --assignee $KUBERNETESCLIENTID --scope /subscriptions/$SUBSCRIPTIONID/resourcegroups/$AKSINFRARESOURCEGROUPNAME
	echo "Running az role assignment create --role "Virtual Machine Contributor" --assignee $KUBERNETESCLIENTID --scope /subscriptions/$SUBSCRIPTIONID/resourcegroups/$AKSINFRARESOURCEGROUPNAME"
	az role assignment create --role "Virtual Machine Contributor" --assignee $KUBERNETESCLIENTID --scope /subscriptions/$SUBSCRIPTIONID/resourcegroups/$AKSINFRARESOURCEGROUPNAME
	echo $"AKS AgentPool Managed Identity configuration for Key Vault access step 1 finished."

	#Create Azure AD Managed Identity specifically for Key Vault, get its ClientiId and PrincipalId so we can assign to it the Reader role in steps 3a, 3b and 3c to.
	echo $"Managing Identity configuration for KV access - step 2 started"
	identityName="AKSKeyVaultUser"
	akskvidentityClientId=$(az identity create -g $AKSINFRARESOURCEGROUPNAME -n $identityName --query 'clientId' -o tsv);
	akskvidentityClientResourceId=$(az identity show -g $AKSINFRARESOURCEGROUPNAME -n $identityName --query 'id' -o tsv)
	principalId=$(az identity show -g $AKSINFRARESOURCEGROUPNAME -n $identityName --query 'principalId' -o tsv)
	echo $"Managing Identity configuration for KV access - step 2 finished"

	echo $"Managing Identity configuration for KV access - step 3 started"
	echo "Sleeping for 60 seconds to wait for MI to be ready"
	sleep 60;
	#KEYVAULT looks like this this /subscriptions/$SUBID/resourceGroups/$kvresourceGroup/providers/Microsoft.KeyVault/vaults/$kvname
	IFS='/' read -r -a kv <<< "$KEYVAULT" #splits the KEYVAULT on slashes and gets last one
	keyVaultName=${kv[-1]}
	keyVaultResourceGroup=${kv[4]}
	keyVaultSubscriptionId=${kv[2]}
	echo $"KEYVAULT is $KEYVAULT"
	echo $"keyVaultName is $keyVaultName"
	echo $"akskvidentityClientId is $akskvidentityClientId"
	echo $"principalId is $principalId"

    rbacEnabled=$(az keyvault show --name $keyVaultName --subscription $keyVaultSubscriptionId --query "properties.enableRbacAuthorization")

    #if rabc, add to rile, if not (policy based) - add policies
    if [ "$rbacEnabled" = true ]; then
		echo $"Setting rbac role."
		echo "Running az role assignment create --role 'Key Vault Secrets User' --assignee $principalId --scope $KEYVAULT"
		az role assignment create --role "Key Vault Secrets User" --assignee $principalId --scope $KEYVAULT
	else
		echo $"Setting policies."
		echo $"Managing Identity configuration for KV access - step 3a started"
		echo "Running az keyvault set-policy -n $keyVaultName --subscription $keyVaultSubscriptionId --secret-permissions get --spn $principalId --query id"
		az keyvault set-policy -n $keyVaultName --subscription $keyVaultSubscriptionId --secret-permissions get --spn $principalId --query id

		echo $"Managing Identity configuration for KV access - step 3b started"
		echo "Running az keyvault set-policy -n $keyVaultName --subscription $keyVaultSubscriptionId --key-permissions get --spn $principalId --query id"
		az keyvault set-policy -n $keyVaultName --subscription $keyVaultSubscriptionId --key-permissions get --spn $principalId --query id

		echo $"Managing Identity configuration for KV access - step 3c started"
		echo "Running az keyvault set-policy -n $keyVaultName --subscription $keyVaultSubscriptionId --certificate-permissions get --spn $principalId --query id"
		az keyvault set-policy -n $keyVaultName --subscription $keyVaultSubscriptionId --certificate-permissions get --spn $principalId --query id

		echo $"Managing Identity configuration for KV access - step 3 finished"
		echo $"Managing Identity configuration for KV access - finished"
	fi
	
fi

#install nginx
echo $"Installing nginx started";

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx

#get profisee nginx settings
curl -fsSL -o nginxSettings.yaml "$REPOURL/Azure-ARM/nginxSettings.yaml";
helm uninstall --namespace profisee nginx

if [ "$USELETSENCRYPT" = "Yes" ]; then
	echo $"Installing nginx for Lets Encrypt and setting the dns name for its IP."
	helm install --namespace profisee nginx ingress-nginx/ingress-nginx --values nginxSettings.yaml --set controller.service.loadBalancerIP=$nginxip --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-dns-label-name"=$DNSHOSTNAME;
else
	echo $"Installing nginx not for Lets Encrypt and not setting the dns name for its IP."
	helm install --namespace profisee nginx ingress-nginx/ingress-nginx --values nginxSettings.yaml --set controller.service.loadBalancerIP=$nginxip
fi

echo $"Installing nginx finished, sleeping for 30s to wait for its IP";

##wait for the ip to be available.  usually a few seconds
sleep 30;
##get ip for nginx
nginxip=$(kubectl --namespace profisee get services nginx-ingress-nginx-controller --output="jsonpath={.status.loadBalancer.ingress[0].ip}");
#
if [ -z "$nginxip" ]; then
	#try again
	echo $"nginx is not configure properly because the LB IP is null, trying again in 60 seconds";
    sleep 60;
	nginxip=$(kubectl --namespace profisee get services nginx-ingress-nginx-controller --output="jsonpath={.status.loadBalancer.ingress[0].ip}");
	if [ -z "$nginxip" ]; then
    	echo $"nginx is not configure properly because the LB IP is null.  Exiting with error";
		exit 1
	fi
fi
echo $"nginx LB IP is $nginxip";

#fix tls variables
echo $"fix tls variables started";
#cert
if [ "$CONFIGUREHTTPS" = "Yes" ]; then
	printf '%s\n' "$TLSCERT" | sed 's/- /-\n/g; s/ -/\n-/g' | sed '/CERTIFICATE/! s/ /\n/g' >> a.cert;
	sed -e 's/^/    /' a.cert > tls.cert;
else    
    echo '    NA' > tls.cert;
fi
rm -f a.cert

#key
if [ "$CONFIGUREHTTPS" = "Yes" ]; then
    printf '%s\n' "$TLSKEY" | sed 's/- /-\n/g; s/ -/\n-/g' | sed '/PRIVATE/! s/ /\n/g' >> a.key;
	sed -e 's/^/    /' a.key > tls.key;
else
	echo '    NA' > tls.key;	    
fi
rm -f a.key

#set dns
if [ "$UPDATEDNS" = "Yes" ]; then
	echo "Update DNS started";
	echo "Delete existing A record - started";
	az network dns record-set a delete -g $DOMAINNAMERESOURCEGROUP -z $DNSDOMAINNAME -n $DNSHOSTNAME --yes;
	echo "Delete existing A record - finished"
	echo "Create new A record - started";
	az network dns record-set a add-record -g $DOMAINNAMERESOURCEGROUP -z $DNSDOMAINNAME -n $DNSHOSTNAME -a $nginxip --ttl 5;
	echo "Create new A record - finished";
	echo "Update DNS finished";
fi
echo $"fix tls variables finished";

#install profisee platform
echo $"install profisee platform statrted";
#set profisee helm chart settings
auth="$(echo -n "$ACRUSER:$ACRUSERPASSWORD" | base64)"
sed -i -e 's/$ACRUSER/'"$ACRUSER"'/g' Settings.yaml
sed -i -e 's/$ACRPASSWORD/'"$ACRUSERPASSWORD"'/g' Settings.yaml
sed -i -e 's/$ACREMAIL/'"support@profisee.com"'/g' Settings.yaml
sed -i -e 's/$ACRAUTH/'"$auth"'/g' Settings.yaml
sed -e '/$TLSCERT/ {' -e 'r tls.cert' -e 'd' -e '}' -i Settings.yaml
sed -e '/$TLSKEY/ {' -e 'r tls.key' -e 'd' -e '}' -i Settings.yaml

rm -f tls.cert
rm -f tls.key

echo $"WEBAPPNAME is $WEBAPPNAME";
WEBAPPNAME="${WEBAPPNAME,,}"
echo $"WEBAPPNAME is now lower $WEBAPPNAME";

#create the azure app id (clientid)
azureAppReplyUrl="${EXTERNALDNSURL}/${WEBAPPNAME}/auth/signin-microsoft"
if [ "$UPDATEAAD" = "Yes" ]; then
	echo "Update AAD started";
	azureClientName="${RESOURCEGROUPNAME}_${CLUSTERNAME}";
	echo $"azureClientName is $azureClientName";
	echo $"azureAppReplyUrl is $azureAppReplyUrl";

	echo "Creating app registration started"
	CLIENTID=$(az ad app create --display-name $azureClientName --reply-urls $azureAppReplyUrl --query 'appId' -o tsv);
	echo $"CLIENTID is $CLIENTID";
	if [ -z "$CLIENTID" ]; then
		echo $"CLIENTID is null fetching";
		CLIENTID=$(az ad app list --display-name $azureClientName --query [0].appId -o tsv)
		echo $"CLIENTID is $CLIENTID";
	fi
	echo "Creating app registration finished"
	echo "Sleeping for 20 seconds to wait for app registration to be ready."
	sleep 20;

	echo "Updating app registration permissions step 1 started"
	#add a Graph API permission of "Sign in and read user profile"
	az ad app permission add --id $CLIENTID --api 00000003-0000-0000-c000-000000000000 --api-permissions e1fe6dd8-ba31-4d61-89e7-88639da4683d=Scope
	az ad sp create --id $CLIENTID
	echo "Updating app registration permissions step 1 finished"

	echo "Updating app registration permissions step 2 started"
	az ad app permission grant --id $CLIENTID --api 00000003-0000-0000-c000-000000000000

	echo "Updating app registration permissions step 2 finished"
	echo "Update AAD finished";
fi

#get storage account pw - if not supplied
if [ "$FILEREPOPASSWORD" = "" ]; then
	echo $"FILEREPOPASSWORD was not passed in, getting it from the storage acount."
	FILEREPOPASSWORD=$(az storage account keys list --resource-group $RESOURCEGROUPNAME --account-name $STORAGEACCOUNTNAME --query '[0].value');
	#clean file repo password - remove quotes
	FILEREPOPASSWORD=$(echo "$FILEREPOPASSWORD" | tr -d '"')
else
	echo $"FILEREPOPASSWORD was passed in, using it."
fi


#If creating a new sql database, create firewall rule for sql server - add outbound ip of aks cluster 
if [ "$SQLSERVERCREATENEW" = "Yes" ]; then
	echo "Adding firewall rule to sql started";
	#strip off .database.windows.net
	IFS='.' read -r -a sqlString <<< "$SQLNAME"
	echo "SQLNAME is $SQLNAME"
	sqlServerName=${sqlString[0],,}; #lowercase is the ,,
	echo "sqlServerName is $sqlServerName"

	echo "Getting ip address from  $AKSINFRARESOURCEGROUPNAME"
	OutIP=$(az network public-ip list -g $AKSINFRARESOURCEGROUPNAME --query "[0].ipAddress" -o tsv);
	echo "OutIP is $OutIP"
	az sql server firewall-rule create --resource-group $RESOURCEGROUPNAME --server $sqlServerName --name "aks lb ip" --start-ip-address $OutIP --end-ip-address $OutIP
	echo "Adding firewall rule to sql finished";
fi

echo "about to set vars in settings.yaml"
#storage vars
FILEREPOUSERNAME="Azure\\\\\\\\${STORAGEACCOUNTNAME}"
FILEREPOURL="\\\\\\\\\\\\\\\\${STORAGEACCOUNTNAME}.file.core.windows.net\\\\\\\\${STORAGEACCOUNTFILESHARENAME}"

#PROFISEEVERSION looks like this profiseeplatform:2020R1.0
#The repo is profiseeplatform or something like it, its everything to the left of the :
#The label is everything to the right of the :

IFS=':' read -r -a repostring <<< "$PROFISEEVERSION"

#lowercase is the ,,
ACRREPONAME="${repostring[0],,}"; 
ACRREPOLABEL="${repostring[1],,}"

#set values in Settings.yaml
sed -i -e 's/$SQLNAME/'"$SQLNAME"'/g' Settings.yaml
sed -i -e 's/$SQLDBNAME/'"$SQLDBNAME"'/g' Settings.yaml
sed -i -e 's/$SQLUSERNAME/'"$SQLUSERNAME"'/g' Settings.yaml
sed -i -e 's/$SQLUSERPASSWORD/'"$SQLUSERPASSWORD"'/g' Settings.yaml
sed -i -e 's/$FILEREPOACCOUNTNAME/'"$STORAGEACCOUNTNAME"'/g' Settings.yaml
sed -i -e 's/$FILEREPOUSERNAME/'"$FILEREPOUSERNAME"'/g' Settings.yaml
sed -i -e 's~$FILEREPOPASSWORD~'"$FILEREPOPASSWORD"'~g' Settings.yaml
sed -i -e 's/$FILEREPOURL/'"$FILEREPOURL"'/g' Settings.yaml
sed -i -e 's/$FILEREPOSHARENAME/'"$STORAGEACCOUNTFILESHARENAME"'/g' Settings.yaml
sed -i -e 's~$OIDCURL~'"$OIDCURL"'~g' Settings.yaml
sed -i -e 's/$CLIENTID/'"$CLIENTID"'/g' Settings.yaml
sed -i -e 's/$OIDCCLIENTSECRET/'"$OIDCCLIENTSECRET"'/g' Settings.yaml
sed -i -e 's/$ADMINACCOUNTNAME/'"$ADMINACCOUNTNAME"'/g' Settings.yaml
sed -i -e 's~$EXTERNALDNSURL~'"$EXTERNALDNSURL"'~g' Settings.yaml
sed -i -e 's/$EXTERNALDNSNAME/'"$EXTERNALDNSNAME"'/g' Settings.yaml
sed -i -e 's~$LICENSEDATA~'"$LICENSEDATA"'~g' Settings.yaml
sed -i -e 's/$ACRREPONAME/'"$ACRREPONAME"'/g' Settings.yaml
sed -i -e 's/$ACRREPOLABEL/'"$ACRREPOLABEL"'/g' Settings.yaml
sed -i -e 's~$PURVIEWURL~'"$PURVIEWURL"'~g' Settings.yaml
sed -i -e 's/$PURVIEWTENANTID/'"$TENANTID"'/g' Settings.yaml
sed -i -e 's/$PURVIEWCLIENTID/'"$PURVIEWCLIENTID"'/g' Settings.yaml
sed -i -e 's/$PURVIEWCLIENTSECRET/'"$PURVIEWCLIENTSECRET"'/g' Settings.yaml
sed -i -e 's/$WEBAPPNAME/'"$WEBAPPNAME"'/g' Settings.yaml
if [ "$USEKEYVAULT" = "Yes" ]; then
	sed -i -e 's/$USEKEYVAULT/'true'/g' Settings.yaml

	sed -i -e 's/$KEYVAULTIDENTITCLIENTID/'"$akskvidentityClientId"'/g' Settings.yaml
	sed -i -e 's~$KEYVAULTIDENTITYRESOURCEID~'"$akskvidentityClientResourceId"'~g' Settings.yaml

	sed -i -e 's/$SQL_USERNAMESECRET/'"$SQLUSERNAME"'/g' Settings.yaml
	sed -i -e 's/$SQL_USERPASSWORDSECRET/'"$SQLUSERPASSWORD"'/g' Settings.yaml
	sed -i -e 's/$TLS_CERTSECRET/'"$TLSCERT"'/g' Settings.yaml
	sed -i -e 's/$LICENSE_DATASECRET/'"$LICENSEDATASECRETNAME"'/g' Settings.yaml
	sed -i -e 's/$KUBERNETESCLIENTID/'"$KUBERNETESCLIENTID"'/g' Settings.yaml

	sed -i -e 's/$KEYVAULTNAME/'"$keyVaultName"'/g' Settings.yaml
	sed -i -e 's/$KEYVAULTRESOURCEGROUP/'"$keyVaultResourceGroup"'/g' Settings.yaml

	sed -i -e 's/$AZURESUBSCRIPTIONID/'"$keyVaultSubscriptionId"'/g' Settings.yaml
	sed -i -e 's/$AZURETENANTID/'"$TENANTID"'/g' Settings.yaml

	$SUBSCRIPTIONID
else
	sed -i -e 's/$USEKEYVAULT/'false'/g' Settings.yaml
fi

if [ "$USELETSENCRYPT" = "Yes" ]; then
	#################################Lets Encrypt Start #####################################
	# Label the namespace to disable resource validation
	echo "Lets Encrypt started";
	kubectl label namespace profisee cert-manager.io/disable-validation=true
	helm repo add jetstack https://charts.jetstack.io
	# Update your local Helm chart repository cache
	helm repo update
	# Install the cert-manager Helm chart
	helm install cert-manager jetstack/cert-manager --namespace profisee --set installCRDs=true --set nodeSelector."kubernetes\.io/os"=linux --set webhook.nodeSelector."kubernetes\.io/os"=linux --set cainjector.nodeSelector."kubernetes\.io/os"=linux --set startupapicheck.nodeSelector."kubernetes\.io/os"=linux
	#wait for the cert manager to be ready
	echo $"Lets Encrypt, waiting for certificate manager to be ready, sleeping for 30s";
	sleep 30;
	sed -i -e 's/$USELETSENCRYPT/'true'/g' Settings.yaml
	echo "Lets Encrypt finshed";
	#################################Lets Encrypt End #######################################
else
	sed -i -e 's/$USELETSENCRYPT/'false'/g' Settings.yaml
fi

#Add settings.yaml as a secret so its always available after the deployment
kubectl delete secret profisee-settings --namespace profisee --ignore-not-found
kubectl create secret generic profisee-settings --namespace profisee --from-file=Settings.yaml

#################################Install Profisee Start #######################################
echo "Install Profisee started $(date +"%Y-%m-%d %T")";
helm repo add profisee $HELMREPOURL
helm repo update
helm uninstall --namespace profisee profiseeplatform
helm install --namespace profisee profiseeplatform profisee/profisee-platform --values Settings.yaml

kubectl delete secret profisee-deploymentlog --namespace profisee --ignore-not-found
kubectl create secret generic profisee-deploymentlog --namespace profisee --from-file=$logfile

#Make sure it installed, if not return error
profiseeinstalledname=$(echo $(helm list --filter 'profisee+' --namespace profisee -o json)| jq '.[].name')
if [ -z "$profiseeinstalledname" ]; then
	echo "Profisee did not get installed.  Exiting with error";
	exit 1
else
	echo "Install Profisee finished $(date +"%Y-%m-%d %T")";
fi;
#################################Install Profisee End #######################################

#wait for pod to be ready (downloaded)
echo "Waiting for pod to be downloaded and be ready..$(date +"%Y-%m-%d %T")";
sleep 30;
kubectl wait --timeout=1800s --for=condition=ready pod/profisee-0 --namespace profisee

echo $"Profisee deploymented finished $(date +"%Y-%m-%d %T")";

result="{\"Result\":[\
{\"IP\":\"$nginxip\"},\
{\"WEBURL\":\"${EXTERNALDNSURL}/${WEBAPPNAME}\"},\
{\"FILEREPOUSERNAME\":\"$FILEREPOUSERNAME\"},\
{\"FILEREPOURL\":\"$FILEREPOURL\"},\
{\"AZUREAPPCLIENTID\":\"$CLIENTID\"},\
{\"AZUREAPPREPLYURL\":\"$azureAppReplyUrl\"},\
{\"SQLSERVER\":\"$SQLNAME\"},\
{\"SQLDATABASE\":\"$SQLDBNAME\"},\
{\"ACRREPONAME\":\"$ACRREPONAME\"},\
{\"ACRREPOLABEL\":\"$ACRREPOLABEL\"}\
]}"

echo $result

kubectl delete secret profisee-deploymentlog --namespace profisee --ignore-not-found
kubectl create secret generic profisee-deploymentlog --namespace profisee --from-file=$logfile

echo $result > $AZ_SCRIPTS_OUTPUT_PATH
