# AKS

Deploy Profisee platform....

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FProfiseeGroup%2Faks%2Fmaster%2Fazuredeploy.json)<a href="http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2FProfiseeGroup%2Faks%2Fmaster%2Fazuredeploy.json" target="_blank">
  <img src="http://armviz.io/visualizebutton.png"/>
</a>


Deploy Profisee platform (latest dev)....

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FProfiseeGroup%2Faks%2Fmaster%2Fazuredeploydev.json)<a href="http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2FProfiseeGroup%2Faks%2Fmaster%2Fazuredeploydev.json" target="_blank">
  <img src="http://armviz.io/visualizebutton.png"/>
</a>

# Prerequisites:

Managed Identity
A managed identiy is required with contributor access either at the subscription level or for the resource group the cluster will be deployed to and the domain resoruce group if the arm template will update the dns information.  If the ar mtemplate will also create the azure ad app registration, then it must have the application developer role assigned to it as well.  Here is an example of how to create the managed identiy using the azure CLI.


  az identity create -g RESOURCE_GROUP -n USER_ASSIGNED_IDENTITY_NAME
  
  az role assignment create --assignee USER_ASSIGNED_IDENTITY_NAME --role 'Contributor'
  
  az role assignment create --assignee USER_ASSIGNED_IDENTITY_NAME --role 'Application Developer'
