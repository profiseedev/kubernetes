# Deploy Profisee platform on to AWS Elastic Kubernetes services (EKS)

The process below explains how to deploy the Profisee platform onto a new AWS EKS cluster. Profisee requires a Windows and a Linux node. Linux nodes are managed nodes

## Prerequisites

1.  The following will be provided by Profisee:
    - Please decide on what DNS (FQDN) you will use to access Profisee at and we will generate a license for it.
    - ACR username, password and token

2.  TLS certificate and the private key.
			
3.  Pick your AWS region, our sample script uses us-east-1.

4.  SQL Server
    - An appropriately sized AWS RDS instance - https://aws.amazon.com/getting-started/hands-on/create-microsoft-sql-db/
    	
		- Goto https://console.aws.amazon.com/rds
		- Click create database
		- Standard Create - Microsoft SQL Server
		- Edition - Choose what you want
		- Version - Choose (default should be fine)
		- Give sql server name as db intance identifier
		- Credentials
			- Master username - login name to use
			- Password - strong password
		- Size - Choose what you need
		- Storage - Defaults should be fine, probably no need for autoscaling
		- Connectivity
			- Public access yes (simpler to debug) - Change to fit your security needs when ready
		- Defaults for the rest of the options
		- Wait for database to be available
	- CLI sample: aws rds create-db-instance --engine sqlserver-ex --db-instance-class db.t3.small --db-instance-identifier <pickyourname> --master-username <pickusername> --master-user-password <PickStrongPassword> --allocated-storage 50
    	
5.  You will need a storage account so please create an EBS volume. It must be created in the same region/zone as the EKS cluster
    - EBS volume - https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ebs-creating-volume.html

	    - https://console.aws.amazon.com/ec2
		- Click Volumes under Elastic Block Store on left
		- Click create volume
		- Choose volume type and size
		- Choose Availability zone, make sure its in the same zone as the EKS cluster
		- Click Create Volume
		- When its finished creating, note the volume id
	- CLI sample:  aws ec2 create-volume --volume-type gp2 --size 1 --availability-zone us-east-1a --region us-east-1
    
6. Configure environment with required tools
	- Use aws cloudshell 
	  - https://dev.to/aws-builders/setting-up-a-working-environment-for-amazon-eks-with-aws-cloudshell-1nn7
	- Use local computer - no cloudshell - https://docs.aws.amazon.com/eks/latest/userguide/getting-started-eksctl.html
	  - Install aws cli - https://awscli.amazonaws.com/AWSCLIV2.msi
	  - Install eksctl - https://docs.aws.amazon.com/eks/latest/userguide/eksctl.html
	  - Install kubectl - https://docs.aws.amazon.com/eks/latest/userguide/install-kubectl.html
          - Setup IAM - https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-quickstart.html#cli-configure-quickstart-creds

7.  Configure DNS	
    - Choose a fully qualified domain name that you would like to use, ex. https://profiseemdm.mycompany.com
    - Create a CNAME record for the profiseemdm hostname with your domain DNS provider and map it to point to xxxxxx.elb.<region>.amazonaws.com (this will be updated later).
      

## Deployment

1.  Edit the provided cluster.yaml to match your requirement and upload it to cloudshell.
	- Download the cluster.yaml
            	
			curl -fsSL -o cluster.yaml https://raw.githubusercontent.com/profiseeadmin/kubernetes/master/AWS-EKS-CLI/cluster.yaml;
		
	- Change the name, region and availability zones
	- Change the instance type(s) to fit your needs.  https://aws.amazon.com/ec2/pricing/on-demand/
	- For more complex deployments, including networking VPC and subnet configurations see https://eksctl.io/usage/schema/
    
2.  Using CLI, create the EKS Cluster.
    
        eksctl create cluster -f cluster.yaml --install-vpc-controllers --timeout 30m

3.  Using CLI, configure kubectl to connect to the newly created cluster.
    
        aws eks --region us-east-1 update-kubeconfig --name <ClusterNAmeYouPicked>

4.  Configure your SQL security group to permit inbound traffic from the cluster's subnet (you can further lock it down to just the kubernetes Windows node IPs. Note: As AWS implements a rolling deprecation of old Windows Server AMIs you will need to implement a maintenance window to update the underlying AMI in the Windows Nodegroup, so please make sure to update your SQL security group with those updated node IPs. 
    - Get the outbound IPs of the cluster.

		kubectl get nodes  -o jsonpath='{.items[*].status.addresses[?(@.type == "ExternalIP")].address}'

	- Click on SQL instance
	- Click on VPC security group
	- Inbound rules
	- Edit inbound rules
	- Add MSSQL for outbound IPs of cluster

5.  Install nginx for AWS

            helm repo add stable https://charts.helm.sh/stable;
            curl -o nginxSettingsAWS.yaml https://raw.githubusercontent.com/Profisee/kubernetes/master/AWS-EKS-CLI/nginxSettingsAWS.yaml;
            kubectl create namespace profisee
	    	helm install nginx stable/nginx-ingress --values nginxSettingsAWS.yaml -n profisee
	    
	- Wait for the load balancer to be provisioned. Go to AWS EC2 load balancing console and wait for the state to go from provisioning to active (approximately 3 minutes).
    
6.  Get nginx IP
    
        kubectl get services nginx-nginx-ingress-controller -n profisee
        #Note the external-ip and update the DNS hostname you created earlier and have it point to it (xxxxxx.elb.<region>.amazonaws.com)

7.  (Optional) - Install cert-manager for Let's Encrypt

	helm install -n profisee cert-manager jetstack/cert-manager --set installCRDs=true --set nodeSelector."beta\.kubernetes\.io/os"=linux --set webhook.nodeSelector."beta\.kubernetes\.io/os"=linux --set cainjector.nodeSelector."beta\.kubernetes\.io/os"=linux

	Set the Settings.yaml useLetsEncrypt flag to true.

8.  Configue Authentication provider
	- Create/configure an auth provider in your auth provider of choice.  eg Azure Active Directory, OKTA
	- Register redirect url http(s)://profiseemdm.mycompany.com/Profisee/auth/signin-microsoft (or .../auth/signing-okta). Make sure that your URL in the the application registration matches. The /signin-microsoft part from the URL can be anything you like so long as the application registration redirect URL and the value in the Settings.yaml template match.
	- Note the clientid, secret and authority url.  The authority url for AAD is https://login.microsoftonline.com/{tenantid}

9.  Create Profisee Settings.yaml
    - Fetch the Settings.yaml template, download the yaml file so you can edit it locally
      
            curl -fsSL -o Settings.yaml https://raw.githubusercontent.com/profiseeadmin/kubernetes/master/AWS-EKS-CLI/Settings.yaml;
    - Update the values
    - Upload to cloudshell    

10.  Install Profisee

            helm repo add profisee https://profiseeadmin.github.io/kubernetes
            helm uninstall -n profisee profiseeplatform
            helm install -n profisee profiseeplatform profisee/profisee-platform --values Settings.yaml

# Verify and finalize:

1.  The initial deployment will have to download the container which takes about 10 minutes.  Verify it's finished downloading the container:

	    #check status and wait for "Pulling" to finish
	    kubectl -n profisee describe pod profisee-0

2.  View the kubernetes logs and wait for it to finish successfully starting up. It takes longer on the first time as it has to create all the objects in the database.

		kubectl logs profisee-0 -n profisee --follow
		
3.  Voila, goto Profisee Platform web portal
	- http(s)://FQDNThatPointsToClusterIP/Profisee
