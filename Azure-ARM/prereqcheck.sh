#!/bin/bash
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
logfile=prereqchecklog_$(date +%Y-%m-%d_%H-%M-%S).out
exec 1>$logfile 2>&1

echo $"Profisee pre-req check started $(date +"%Y-%m-%d %T")";

printenv;

if [ -z "$RESOURCEGROUPNAME" ]; then
	RESOURCEGROUPNAME=$ResourceGroupName
fi

if [ -z "$SUBSCRIPTIONID" ]; then
	SUBSCRIPTIONID=$SubscriptionId
fi

#az login --identity

az version;
success='false'

echo $"RESOURCEGROUPNAME is $RESOURCEGROUPNAME"
echo $"SUBSCRIPTIONID is $SUBSCRIPTIONID"
echo $"MANAGEDIDENTITYNAME is $MANAGEDIDENTITYNAME"

#MI looks like this
##{"type":"UserAssigned","userAssignedIdentities":{"/subscriptions/subscriptionId/resourceGroups/resourceGroupName/providers/Microsoft.ManagedIdentity/userAssignedIdentities/managedIdentityName":{}}}
echo $MANAGEDIDENTITYNAME >> mi.json
mi=$(echo $(jq '.userAssignedIdentities' mi.json)| tr -d '{' | tr -d '"' | tr -d '}' | tr -d ':')

#MI looks like this after the cleanup
#/subscriptions/subscriptionId/resourceGroups/resourceGroupName/providers/Microsoft.ManagedIdentity/userAssignedIdentities/managedIdentityName

IFS='/' read -r -a miparts <<< "$mi" #splits the mi on slashes
mirg=${miparts[4]}
miname=${miparts[8]}

#remove white space
miname=$(echo $miname | xargs)

#get the id of the current user (MI)
currentIdentityId=$(az identity show -g $mirg -n $miname --query principalId -o tsv)

#Check to make sure you have effective contributor access to the resource group.  at RG or sub levl
#check subscription level
#az role assignment list --all --assignee $currentIdentityId --output json --include-inherited --query [].[roleDefinitionName,scope] | jq -r '.value[] | select(.id)'

echo "Checking contributor level for subscription"
subscriptionContributor=$(az role assignment list --all --assignee $currentIdentityId --output json --include-inherited --query "[?roleDefinitionName=='Contributor' && scope=='/subscriptions/$SUBSCRIPTIONID'].roleDefinitionName" --output tsv)
if [ -z "$subscriptionContributor" ]; then
	echo "Managed identity is NOT contributor at subscription level, checking resource group"
	#not subscription level, check resource group level
	rgContributor=$(az role assignment list --all --assignee $currentIdentityId --output json --include-inherited --query "[?roleDefinitionName=='Contributor' && scope=='/subscriptions/$SUBSCRIPTIONID/resourceGroups/$RESOURCEGROUPNAME'].roleDefinitionName" --output tsv)
	if [ -z "$rgContributor" ]; then
		echo "Managed identity is not contributor to resource group.  Exiting with error"
		exit 1
	else
		echo "Managed identity is contributor to resource group."
	fi

	#If updating dns, check to make sure you have effective contributor access to the dns resource group
	if [ "$UPDATEDNS" = "Yes" ]; then
		echo "Checking contributor for DNS resource group"
		dnsrgContributor=$(az role assignment list --all --assignee $currentIdentityId --output json --include-inherited --query "[?roleDefinitionName=='Contributor' && scope=='/subscriptions/$SUBSCRIPTIONID/resourceGroups/$DOMAINNAMERESOURCEGROUP'].roleDefinitionName" --output tsv)
		if [ -z "$dnsrgContributor" ]; then
			err="Managed identity is not contributor to DNS resource group.  Exiting with error"
			echo $err
			result="{\"Result\":[\
			{\"SUCCESS\":\"$success\"},
			{\"ERROR\":\"$err\"}\
			]}"
			echo $result > $AZ_SCRIPTS_OUTPUT_PATH
			exit 1
		else
			echo "Managed identity is contributor to DNS resource group."
		fi
	fi

	#If using keyvault, check to make sure you have effective contributor access to the keyvault
	if [ "$USEKEYVAULT" = "Yes" ]; then
		echo "Checking contributor for keyvault"
		KEYVAULT=$(echo $KEYVAULT | xargs)
		kvContributor=$(az role assignment list --all --assignee $currentIdentityId --output json --include-inherited --query "[?roleDefinitionName=='Contributor' && scope=='$KEYVAULT'].roleDefinitionName" --output tsv)
		if [ -z "$kvContributor" ]; then
			echo "Managed identity is not contributor to KeyVault.  Exiting with error"
			exit 1
		else
			echo "Managed identity is contributor to KeyVault."
		fi
	fi

else
	echo "Managed identity is contributor at subscription level."
fi

#If using keyvault, check to make sure you have Managed Identity Contributor role
if [ "$USEKEYVAULT" = "Yes" ]; then
	echo "Checking Managed Identity Contributor"
	subscriptionMIContributor=$(az role assignment list --all --assignee $currentIdentityId --output json --include-inherited --query "[?roleDefinitionName=='Managed Identity Contributor' && scope=='/subscriptions/$SUBSCRIPTIONID'].roleDefinitionName" --output tsv)
	if [ -z "$subscriptionMIContributor" ]; then
		echo "Managed identity is not Managed Identity Contributor.  Exiting with error"
		exit 1
	else
		echo "Managed identity is Managed Identity Contributor."
	fi
fi

#If updating AAD, make sure you have Application Developer role
if [ "$UPDATEAAD" = "Yes" ]; then
	echo "Checking Application Developer Role"
	appDevRoleId=$(az rest --method get --url https://graph.microsoft.com/v1.0/directoryRoles/ | jq -r '.value[] | select(.displayName | contains("Application Developer")).id')
	minameinrole=$(az rest --method GET --uri "https://graph.microsoft.com/beta/directoryRoles/$appDevRoleId/members" | jq -r '.value[] | select(.displayName | contains("'"$miname"'")).displayName')
	if [ -z "$minameinrole" ]; then
		echo "Managed identity is not in application developer role.  exiting with error"
		exit 1
	else
		echo "Managed identity is in application developer role."
	fi
fi

success='true'


echo $"Profisee pre-req check finished $(date +"%Y-%m-%d %T")";

result="{\"Result\":[\
{\"SUCCESS\":\"$success\"},
]}"
echo $result > $AZ_SCRIPTS_OUTPUT_PATH
echo $result

echo $result > $AZ_SCRIPTS_OUTPUT_PATH
