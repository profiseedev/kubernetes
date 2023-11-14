# AWS Profisee EKS Deployment CloudFormation Template

This README outlines the deployment process for the AWS CloudFormation template designed to create a fresh AWS environment for the Profisee platform with an Amazon EKS cluster and associated resources.

## Overview

This CloudFormation template is designed to set up the following resources in a new AWS environment:

- Amazon EKS Cluster
- EKS Node Groups for both Linux and Windows
- IAM Roles for EKS
- Amazon RDS MySQL Instance
- ACM Certificate for a domain
- Security Groups, including one for the Ingress Controller
- A new VPC with associated Subnets

## Prerequisites

Before you begin, make sure you have:

- An AWS account with appropriate permissions
- AWS CLI installed and configured on your machine
- Basic knowledge of AWS EKS, RDS, VPC, and other AWS services

## Template Resource Details

### EKS Cluster (`EKSCluster`)

Configures a new EKS cluster named `ProfiseeDemo`. Ensure that the Kubernetes version and other settings meet your specific needs.

### EKS Node Groups (`LinuxNodeGroup` & `WindowsNodeGroup`)

Creates node groups for running Linux and Windows workloads, with configurable instance types, scaling settings, and disk sizes.

### IAM Roles (`NodeInstanceRole` & `RBACRole`)

Defines necessary IAM roles to grant EKS nodes and services the required permissions for interacting with other AWS services.

### RDS Instance (`RDSInstance`)

Provisions a new RDS instance with MySQL, tailored for database needs of applications running on EKS.

### ACM Certificate (`ACMCertificate`)

Generates an ACM certificate for your specified domain, crucial for secure communications.

### Ingress Controller Security Group (`IngressControllerSetup`)

Establishes a security group for the Ingress Controller, enabling traffic on ports 80 and 443.

### VPC and Subnets (`VPC`, `PublicSubnet`, `PrivateSubnet`)

Creates a new VPC and associated subnets, laying the foundation for network infrastructure.

## Deployment Instructions

1. **Prepare for Deployment**:
   - Ensure all prerequisites are met.
   - Update the template with your specific details, such as domain name for ACM Certificate, and database credentials for the RDS instance.

2. **Upload and Deploy the Template**:
   - Via AWS Management Console: 
     - Navigate to the CloudFormation service.
     - Choose 'Create Stack' and upload the template.
   - Via AWS CLI: 
     - Use the command: `aws cloudformation create-stack --stack-name ProfiseeEKS --template-body file://path_to_template/template.yaml`.

3. **Monitor Stack Creation**:
   - Track the progress in the AWS CloudFormation console.
   - Wait for the status to change to `CREATE_COMPLETE`.

4. **Post-Deployment Steps**:
   - After successful creation, perform any additional configurations needed for your Kubernetes cluster, like setting up Ingress Controllers or deploying specific services.
   - These Kubernetes-specific configurations are outside the scope of CloudFormation and must be done using `kubectl` or `helm`.

5. **Validate the Deployment**:
   - Ensure all resources are correctly created and configured.
   - Check the AWS Management Console to confirm the setup.

## Notes and Best Practices

- **Customization**: Modify the template as needed to fit your specific AWS environment and requirements.
- **Security**: Review and tighten security group rules and IAM policies as per your organizational standards.
- **Updates**: Regularly check for updates in AWS services and adjust the template accordingly.
- **Testing**: Before deploying in a production environment, it's recommended to test the template in a staging environment.

## Troubleshooting

- If the stack fails to create, review the events tab in the CloudFormation console for specific error messages.
- Ensure that the AWS CLI is configured correctly with the necessary permissions.
- Validate that the values provided in the template (like domain names and credentials) are accurate.