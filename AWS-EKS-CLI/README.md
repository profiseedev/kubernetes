# AWS Profisee Deployment

Deploying the Profisee platform on AWS EKS involves a variety of AWS services and tools. Below is a detailed guide through the process, providing specific AWS CLI, eksctl, kubectl, and helm commands to use at each step.

## Prerequisites:
1. Ensure the following tools are installed:
   - AWS CLI: [Installation Guide](https://aws.amazon.com/cli/)
   - helm: [Installation Guide](https://helm.sh/docs/intro/install/)
   - eksctl: [Installation Guide](https://eksctl.io/introduction/#installation)
     - **Important**: Make sure that the version of `eksctl` is compatible with your `kubectl` version. `eksctl` releases are independent of `kubectl` releases, but since they both interact with your Kubernetes cluster, it’s crucial to ensure compatibility to avoid any potential issues.
       - To upgrade `eksctl`, follow the instructions provided in the [official eksctl documentation](https://eksctl.io/introduction/#installation).
       - After upgrading, verify the installed version:
         ```sh
         eksctl version
         ```
   - kubectl (latest stable version recommended): [Installation Guide](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
     - **Important**: It is crucial to have the latest stable version of `kubectl` to ensure compatibility and security. The recommended version as of now is 1.27.
       - If you already have an older version of `kubectl` installed, you can upgrade it using the package manager of your choice. Below are the general steps to upgrade `kubectl`.
       - **On macOS:**
         ```sh
         brew upgrade kubectl
         ```
       - **On Linux:**
         - If you installed using a package manager like apt or yum:
           ```sh
           sudo apt update && sudo apt install -y kubectl
           # OR
           sudo yum update && sudo yum install -y kubectl
           ```
         - If you installed by downloading the binary, download the latest version from the [official releases page](https://kubernetes.io/releases/download/), and replace the binary in your PATH.
       - **On Windows:**
         - If you installed using Chocolatey:
           ```sh
           choco upgrade kubernetes-cli
           ```
         - If you downloaded the binary, download the latest version from the [official releases page](https://kubernetes.io/releases/download/), and replace the binary in your PATH.
       - After upgrading, verify the installed version:
         ```sh
         kubectl version --client
         ```
       - Upgrading `kubectl` does not affect existing Kubernetes clusters, but it is important to ensure that your `kubectl` version is compatible with the version of your cluster. As a rule of thumb, `kubectl` should be within one minor version of your cluster. For example, a 1.18 `kubectl` should work with 1.17, 1.18, and 1.19 clusters.

     - If you've deployed applications using an older version of `kubectl`, there should be no immediate impact when you upgrade `kubectl`. However, you should check the [official Kubernetes deprecation policy](https://kubernetes.io/docs/reference/using-api/deprecation-policy/) to ensure that any deprecated features you might be using will continue to be supported in the version of the cluster you are using.


## 1. Configure AWS CLI:
Run the following command and enter your AWS Access Key ID, Secret Access Key, Default region name, and Default output format (json is recommended).
```sh
aws configure
```

## 2. Create an RDS SQL Server Instance:
Before proceeding, it’s crucial to select the appropriate size for your RDS SQL Server Instance to ensure optimal performance. The required size depends on various factors. We recommend referring to our [Sizing Guide](https://support.profisee.com/wikis/profiseeplatform/system_requirements_for_profisee_server) to help you make an informed decision.

Once you have determined the suitable instance size, replace the placeholders in the command below with your specific configurations. The example below demonstrates the creation of an RDS SQL Server Instance with a t4g.xlarge instance class. Adjust the `--db-instance-class` and other parameters according to your needs.
```sh
aws rds create-db-instance \
    --engine sqlserver-ex \
    --db-instance-class db.t3.xlarge \
    --db-instance-identifier profiseedemo \
    --master-username sqladmin \
    --master-user-password YourStrongPassword!123 \
    --allocated-storage 20 \
    --publicly-accessible \
    --region your-region-name
```

## 3. Create an EBS Volume:
Replace us-east-1a and us-east-1 with your specific availability zone and region.
```sh
aws ec2 create-volume --volume-type gp2 --size 10 --availability-zone us-east-1a --region us-east-1
```

## 4. Configure your Environment
Ensure that aws-cli, eksctl, kubectl, and helm are installed and properly configured in your local environment.

## 5. Create the EKS Cluster:
5.1 Download and modify the cluster.yaml file.

5.2 Run the following command to create the EKS cluster:
```sh
eksctl create cluster -f cluster.yaml --install-vpc-controllers --timeout 30m
```

## 6. Configure kubectl:
Replace `YourClusterName` with the name of your EKS cluster.
```sh
aws eks --region your-region-name update-kubeconfig --name YourClusterName
```

## 7. Update RDS Security Group:
7.1  Obtain the node IPs using:
```sh
kubectl get nodes -o jsonpath="{.items[*].status.addresses[?(@.type=='ExternalIP')].address}"
```
7.2 Add the obtained IPs to your RDS instance's security group inbound rules using AWS CLI.

7.3 List all RDS instances and their associated security groups:
```sh
aws rds describe-db-instances --query "DBInstances[*].[DBInstanceIdentifier, VpcSecurityGroups[*].VpcSecurityGroupId]" --output table
```
Note the associated security group ID(s) for your RDS instance.

7.4 Add inbound rules to the security group to allow connections from the IP addresses obtained:
```sh
aws ec2 authorize-security-group-ingress --group-id sg-xxxxxxxxxxxxxxxxx --protocol tcp --port 3306 --cidr IP_ADDRESS/32
```
* Replace sg-xxxxxxxxxxxxxxxxx with your RDS security group ID.
* Replace 3306 with the port number that your RDS instance is using.
* Replace IP_ADDRESS with the IP address of your EKS node.

Ensure that your AWS CLI is configured with the necessary permissions to modify security group rules, and ensure that the security group’s outbound rules allow the response traffic from your RDS instance back to your EKS nodes.

## 8. Install nginx on EKS:
Before installing NGINX Ingress Controller, you need to set up the necessary RBAC (Role-Based Access Control) roles and bindings.
### Creating NGINX RBAC Configuration:
Create a file named `nginx-rbac.yaml` (or download the file from the repository) and add the following content to define the necessary ClusterRole and ClusterRoleBinding for NGINX:

```yaml
   apiVersion: rbac.authorization.k8s.io/v1
   kind: ClusterRole
   metadata:
     name: nginx-ingress-clusterrole
   rules:
   - apiGroups:
     - networking.k8s.io
     resources:
     - ingressclasses
     verbs:
     - get
     - list
     - watch
   ---
   apiVersion: rbac.authorization.k8s.io/v1
   kind: ClusterRoleBinding
   metadata:
     name: nginx-ingress-clusterrolebinding
   roleRef:
     apiGroup: rbac.authorization.k8s.io
     kind: ClusterRole
     name: nginx-ingress-clusterrole
   subjects:
   - kind: ServiceAccount
     name: nginx-ingress-nginx
     namespace: profisee
```
This configuration sets up the necessary permissions for NGINX to interact with Ingress resources in your cluster. Apply the RBAC configuration:
```sh
kubectl apply -f nginx-rbac.yaml
```

NOTE: Before moving forward, ensure you have created the Amazon EBS CSI driver IAM role. This role is necessary for the EBS CSI driver to interact with AWS services on behalf of your Kubernetes cluster.

To create the Amazon EBS CSI driver IAM role, run the following command, replacing `<CLUSTERNAME>` with the name of your actual EKS cluster and `<AWSACCOUNTID>` with your AWS account ID:

```shell
aws eks create-addon --cluster-name <CLUSTERNAME> --addon-name aws-ebs-csi-driver \
  --service-account-role-arn arn:aws:iam::<AWSACCOUNTID>:role/AmazonEKS_EBS_CSI_DriverRole
```

### Installing NGINX Ingress Controller
```sh
helm repo add stable https://charts.helm.sh/stable
curl -o nginxSettingsAWS.yaml https://raw.githubusercontent.com/Profisee/kubernetes/master/AWS-EKS-CLI/nginxSettingsAWS.yaml
kubectl create ns profisee
helm install nginx ingress-nginx/ingress-nginx --values nginxSettingsAWS.yaml -n profisee
```
Wait for the load balancer to be active, then obtain the nginx IP:
```sh
kubectl get services nginx-ingress-nginx-controller -n profisee
```
Update your DNS to point to this IP.

### 9. Configuring TLS with cert-manager and Let's Encrypt

To secure our Kubernetes services, we will configure TLS using cert-manager and Let's Encrypt, avoiding the use of wildcard certificates and nip.io domains for better security practices and alignment with enterprise standards.

#### Step 1: Install cert-manager

Install cert-manager in your Kubernetes cluster to manage certificates lifecycle:

```sh
helm install -n profisee cert-manager jetstack/cert-manager -n default --set installCRDs=true --set nodeSelector."beta.kubernetes.io/os"=linux --set webhook.nodeSelector."beta.kubernetes.io/os"=linux --set cainjector.nodeSelector."beta.kubernetes.io/os"=linux
```
Ensure that all the pods are running:
```sh
kubectl get pods -n cert-manager
```

#### Step 2: Configure Let's Encrypt Issuer
Create a Let's Encrypt issuer (or download the file from the repository), replace email@example.com with your email address:
```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    email: email@example.com
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
```
Apply this configuration:
```sh
kubectl apply -f letsencrypt-issuer.yaml
```

#### Step 3: Configure TLS Ingress
Create an Ingress resource that uses the Let's Encrypt issuer to obtain a TLS certificate (or download the file from the repository). Make sure to replace yourdomain.com and my-service with your actual domain and service name:
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: tls-ingress
  namespace: default
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  tls:
  - hosts:
    - yourdomain.com
    secretName: yourdomain-tls
  rules:
  - host: yourdomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: profisee-service
            port:
              number: 80
```
Apply this configuration:
```sh
kubectl apply -f tls-ingress.yaml
```

#### Step 4: Verify Certificate Issuance
Ensure that the certificate has been successfully issued:
```sh
kubectl describe certificate yourdomain-tls
```
Look for the ‘Issued’ status in the ‘Events’ section.

#### Step 5: Test Your Configuration
After the certificate has been issued, access your application via HTTPS to confirm that TLS is properly configured:
```sh
curl https://yourdomain.com
```
This should return the content served by your application over a secure connection.

## 10. Configure Authentication Provider:
Register the redirect URL and obtain the client ID, secret, and authority URL.

## 11. Create and Configure Profisee Settings.yaml:
11.1 Download and modify the settings.yaml file.
```sh
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/profiseedev/kubernetes/master/AWS-EKS-CLI/Settings.yaml" -OutFile "Settings.yaml"
```
11.2 Add the SQL Server connection string, authentication settings, and other necessary configurations.

## 12. Deploy Profisee:
12.1 Add Profisee Helm Repository:
```sh
helm repo add profisee "https://profiseedev.github.io/kubernetes"
```
12.2 Install Profisee:
```sh
helm install -n profisee profiseeplatform profisee/profisee-platform --values Settings.yaml
```
### Important Note on Authentication for Profisee

When configuring Profisee for authentication, it is essential to use an OpenID Connect (OIDC) compliant Identity Provider (IdP) such as Azure AD, Okta, or Google Identity. Please ensure that you do not attempt to configure AWS credentials as your IdP for Profisee. The OIDC provider will be responsible for authenticating users and providing the necessary tokens for access control.

For example, if you are integrating with Azure AD, you will need to mount a volume in your container that provides access to a secret store where Azure AD tokens are kept. This token is used by the application hosted within the container to perform authentication redirects to Azure AD, receive tokens, and manage user sessions in compliance with OIDC standards.

Ensure that your identity provider and the necessary secrets are correctly configured before deploying Profisee with the Helm chart.

## 13. Verify and Finalize:
Check Pod Status:
```sh
kubectl -n profisee describe pod profisee-0
kubectl logs profisee-0 -n profisee --f
http(s)://FQDNThatPointsToClusterIP/Profisee
```

## 14. Switching from a Windows 2019 Node to Windows 2022
If your EKS cluster is currently running Windows 2019 nodes and you want to switch to Windows 2022 nodes, follow these steps:

#### Step 1: Drain the Windows 2019 Node
First, you need to drain the node to ensure that no new pods are scheduled on it and that existing pods are gracefully terminated.
```sh
kubectl drain <windows-2019-node-name> --ignore-daemonsets --force
```

#### Step 2: Update the Nodegroup
Update the nodegroup to use the WindowsServer2022FullContainer AMI family.
```sh
eksctl update nodegroup --cluster=<cluster-name> --name=<nodegroup-name> --kubernetes-version auto
```

#### Step 3: Create a New Nodegroup with Windows 2022
Create a new nodegroup with the Windows 2022 AMI family and desired instance type.
```sh
eksctl create nodegroup --cluster=<cluster name> --node-ami-family=WindowsServer2022FullContainer --nodes-min=1 --nodes-max=1 --node-type=m5.xlarge --node-volume-size=100 --region=us-east-1 --name=<new-nodegroup-name>

```

#### Step 4: Delete the Windows 2019 Nodegroup
Once all the pods are running on the new Windows 2022 nodegroup, you can delete the old Windows 2019 nodegroup.
```sh
eksctl delete nodegroup --cluster=<cluster-name> --name=<windows-2019-nodegroup-name>
```
This will gracefully handle the transition from Windows 2019 to Windows 2022 nodes in your EKS cluster.