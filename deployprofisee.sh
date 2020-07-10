#!/bin/bash
#install the aks cli since this script runs in az 2.0.80 and the az aks was not added until 2.5
az aks install-cli;
#get the aks creds, this allows us to use kubectl commands if needed
az aks get-credentials --resource-group $RESOURCEGROUPNAME --name $CLUSTERNAME --overwrite-existing;

#install helm
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3;
chmod 700 get_helm.sh;
./get_helm.sh;

#install nginx
helm repo add stable https://kubernetes-charts.storage.googleapis.com/;
#get profisee nginx settings
curl -fsSL -o n.yaml https://raw.githubusercontent.com/Profisee/kubernetes/master/scripts/nginxSettings.yaml;
helm uninstall nginx
helm install nginx stable/nginx-ingress --values n.yaml --set controller.service.loadBalancerIP=$publicInIP;

#wait for the ip to be available.  usually a few seconds
sleep 30;
#get ip for nginx
nginxip=$(kubectl get services nginx-nginx-ingress-controller --output="jsonpath={.status.loadBalancer.ingress[0].ip}");
echo $nginxip;

#fix tls variables
#cert
printf '%s\n' "$TLSCERT" | sed 's/- /-\n/g; s/ -/\n-/g' | sed '/CERTIFICATE/! s/ /\n/g' >> a.cert;
sed -e 's/^/    /' a.cert > afinal.cert;

#key
printf '%s\n' "$TLSKEY" | sed 's/- /-\n/g; s/ -/\n-/g' | sed '/PRIVATE/! s/ /\n/g' >> a.key;
sed -e 's/^/    /' a.key > afinal.key;

#set dns
az network dns record-set a delete -g $DOMAINNAMERESOURCEGROUP -z $DNSDOMAINNAME -n $DNSHOSTNAME --yes;
az network dns record-set a add-record -g $DOMAINNAMERESOURCEGROUP -z $DNSDOMAINNAME -n $DNSHOSTNAME -a $nginxip --ttl 5;

#install profisee platform
#get profisee helm chart settings
curl -fsSL -o s.yaml https://raw.githubusercontent.com/profiseegroup/aks/master/Settings.yaml
auth="$(echo -n "$ACRUSER:$ACRUSERPASSWORD" | base64)"
sed -i -e 's/AUTH_USERNAME/'"$ACRUSER"'/g' s.yaml
sed -i -e 's/AUTH_PASSWORD/'"$ACRUSERPASSWORD"'/g' s.yaml
sed -i -e 's/AUTH_EMAIL/'"support@profisee.com"'/g' s.yaml
sed -i -e 's/AUTH_AUTH/'"$auth"'/g' s.yaml
sed -e '/TLSCERT_DATA/ {' -e 'r afinal.cert' -e 'd' -e '}' -i s.yaml
sed -e '/TLSKEY_DATA/ {' -e 'r afinal.key' -e 'd' -e '}' -i s.yaml

#create the azure app id (clientid)
azureAppReplyUrl="${EXTERNALDNSURL}/profisee/auth/signin-microsoft"
azureClientName="${RESOURCEGROUPNAME}_${CLUSTERNAME}";
azureClientId=$(az ad app create --display-name $azureClientName --reply-urls $azureAppReplyUrl --query 'appId');

#get storage account pw
storageAccountPassword=$(az storage account keys list --resource-group $RESOURCEGROUPNAME --account-name $STORAGEACCOUNTNAME --query '[0].value');

#storage vars
FILEREPOUSERNAME="Azure\\${STORAGEACCOUNTNAME}"
FILEREPOURL="\\\\${STORAGEACCOUNTNAME}.file.core.windows.net\\${STORAGEACCOUNTFILESHARENAME}"

if [ "$PROFISEEVERSION" = "2020 R1" ]; then
    ACRREPONAME='profisee2020r1';
	ACRREPOLABEL='GA';
else
    ACRREPONAME='profisee2020r2';
	ACRREPOLABEL='latest';
fi

helm repo add profisee https://profisee.github.io/kubernetes
helm uninstall profiseeplatform2020r1
helm install profiseeplatform2020r1 profisee/profisee-platform --values s.yaml --set sqlServer.name=$SQLNAME --set sqlServer.databaseName=$SQLDBNAME --set sqlServer.userName=$SQLUSERNAME --set sqlServer.password=$SQLUSERPASSWORD --set profiseeRunTime.fileRepository.userName=$FILEREPOUSERNAME --set profiseeRunTime.fileRepository.password=$storageAccountPassword --set profiseeRunTime.fileRepository.location=$FILEREPOURL --set profiseeRunTime.oidc.authority=$OIDCURL --set profiseeRunTime.oidc.clientId=$CLIENTID --set profiseeRunTime.oidc.clientSecret=$OIDCCLIENTSECRET --set profiseeRunTime.adminAccount=$ADMINACCOUNTNAME --set profiseeRunTime.externalDnsUrl=$EXTERNALDNSURL --set profiseeRunTime.externalDnsName=$EXTERNALDNSNAME --set licenseFileData=$LICENSEDATA --set image.repository=$ACRREPONAME --set image.tag=$ACRREPOLABEL

result="{\"Result\":[\
{\"nginxip\":\"$nginxip\"},\
{\"azureAppReplyUrl\":\"$azureAppReplyUrl\"},\
{\"FILEREPOUSERNAME\":\"$FILEREPOUSERNAME\"},\
{\"FILEREPOURL\":\"$FILEREPOURL\"},\
{\"CLIENTID\":\"$CLIENTID\"}\
{\"ACRREPONAME\":\"$ACRREPONAME\"}\
{\"ACRREPOLABEL\":\"$ACRREPOLABEL\"}\
]}"
echo $result > $AZ_SCRIPTS_OUTPUT_PATH
