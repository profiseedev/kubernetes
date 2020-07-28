# AKS

Deploy Profisee platform....

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FProfiseeGroup%2Faks%2Fmaster%2Fazuredeploy.json)<a href="http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2FProfiseeGroup%2Faks%2Fmaster%2Fazuredeploy.json" target="_blank">
  <img src="http://armviz.io/visualizebutton.png"/>
</a>


Deploy Profisee platform (latest dev)....

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FProfiseeGroup%2Faks%2Fmaster%2Fazuredeploydev.json)

# Prerequisites:

1.  Managed Identity
    - You must have a managed identity configured ahead of time.  The MI must have Contributor role for the resource group, and the DNS zone resource group.  If creating an AAZ app registration, the MI must have the Application Developer role assigned to it.  There is already one configure in the Profisee R&D azure subscription call ProfiseePlatformDeployment.   https://docs.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/how-to-manage-ua-identity-portal
2.  License
    - Profisee license associated with the dns for the environment
    - Token for access to the profisee container

