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
az identity create -g <RESOURCE GROUP> -n <USER ASSIGNED IDENTITY NAME>
  
az role assignment create --assignee <USER ASSIGNED IDENTITY NAME> --role 'Contributor'
  
az role assignment create --assignee <USER ASSIGNED IDENTITY NAME> --role 'Application Developer'
