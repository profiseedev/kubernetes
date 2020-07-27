# AKS

Deploy Profisee platform....

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FProfiseeGroup%2Faks%2Fmaster%2Fazuredeploy.json)<a href="http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2FProfiseeGroup%2Faks%2Fmaster%2Fazuredeploy.json" target="_blank">
  <img src="http://armviz.io/visualizebutton.png"/>
</a>


Deploy Profisee platform (latest dev)....

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FProfiseeGroup%2Faks%2Fmaster%2Fazuredeploydev.json)

# Prerequisites:

A user assigned managed identity is required with contributor access either at the subscription level or contributor access to the resource group the cluster will be deployed to and the domain resoruce group if the arm template will update the dns information.  If the arm template will also create the azure ad app registration, then it must have the application developer role assigned to it as well. https://docs.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/how-to-manage-ua-identity-portal

