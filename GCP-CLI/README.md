# Deploy Profisee platform on to Google Cloud Platform (GCP) Kubernetes

This explains the process to deploy the Profisee platform onto a new GCP Kubernetes cluster

## Prerequisites

1.  License
    - Profisee license associated with the dns for the environment
    - ACR username, password and token 

2.  Https certificate including the private key

3.  SQL Server
    - GCP SqlServer instance - https://cloud.google.com/sql-server#section-4
    - Make sure the SQL Server is accessable by the cluster
	- CLI example - gcloud sql instances create profiseesql --database-version=SQLSERVER_2017_EXPRESS --cpu=1 --memory=3840MiB --root-password=Password123 --zone=us-east1-b

4.  Disk
    - Create https://console.cloud.google.com/compute/disks
	- More docs https://cloud.google.com/compute/docs/disks/
	- More info https://kubernetes.io/docs/concepts/storage/volumes/#gce-create-persistent-disk
	- CLI sample - gcloud compute disks create profiseefileshare --size=10GB --zone=us-east1-b --type=pd-balanced
        
 
## Deployment

1.  Open cloud shell
	- Goto GCP console - https://console.cloud.google.com/
	- Open up cloud shell - https://cloud.google.com/shell/docs/using-cloud-shell
    
2.  Create the main cluster
    - pick sizes - https://cloud.google.com/compute/vm-instance-pricing

        gcloud container clusters create profiseedemo --enable-ip-alias --num-nodes=1 --region us-east1-b --machine-type=e2-standard-2

3.  Add windows node pool
    
        gcloud container node-pools create windows-pool --cluster=profiseedemo --image-type=WINDOWS_LTSC --no-enable-autoupgrade --machine-type=e2-standard-4 --region us-east1-b --num-nodes=1

3.  Install nginx

            ##helm repo add stable https://charts.helm.sh/stable;
			#helm repo add nginx https://helm.nginx.com/stable
            helm repo add nginx https://kubernetes.github.io/ingress-nginx

            #get the nginx settings for gcp
            curl -fsSL -o nginxSettingsGCP.yaml https://raw.githubusercontent.com/Profisee/kubernetes/master/GCP-CLI/nginxSettingsGCP.yaml;
            #create profisee namespace of needed
			kubectl create namespace profisee

			#helm install nginx nginx/nginx-ingress --values nginxSettingsGCP.yaml --namespace profisee
            helm install --namespace profisee nginx nginx/ingress-nginx --values nginxSettingsGCP.yaml
    
3.  Get nginx IP and update DNS
            
		#kubectl get services nginx-nginx-ingress-controller --namespace profisee
        kubectl get services nginx-ingress-nginx-controller --namespace profisee
        #Note the external-ip (might take a few minutes) and you need to create a A record in dns to point to it.  

4.  Create Profsiee Settings.yaml
    - Fetch the Settings.yaml template
      
            curl -fsSL -o Settings.yaml https://raw.githubusercontent.com/Profisee/kubernetes/master/GCP-CLI/Settings.yaml;
    -Update all the values
    -upload to cloud shell

5.  Install Profisee

            helm repo add profisee https://profisee.github.io/kubernetes
            helm uninstall profiseeplatform --namespace profisee
            helm install profiseeplatform profisee/profisee-platform --values Settings.yaml --namespace profisee
            
# Verify:

1.  The initial deploy will have to download the container which takes about 10 minutes.  Verify its finished downloading the container:

		kubectl describe pod profisee-0 #check status and wait for "Pulling" to finish

1.  Container can be accessed with the following command:
    
        kubectl exec -it profisee-0 powershell

2.  System logs can be accessed within the container with the following command:
    
        Get-Content C:\Profisee\Configuration\LogFiles\SystemLog.log
	


