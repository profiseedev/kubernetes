# AWS Profisee EKS Deployment CloudFormation Template

This CloudFormation template is designed to create an AWS EKS (Elastic Kubernetes Service) Cluster along with the necessary supporting AWS infrastructure. This includes a VPC, subnets, NAT gateway, Internet Gateway, security groups, IAM roles, and an RDS SQL Server instance.

## Description

The template sets up the following resources:

- **VPC**: A virtual private cloud configured with a CIDR block of `10.0.0.0/16`.
- **Internet Gateway**: Attached to the VPC for internet access.
- **Public and Private Subnets**: Used for organizing resources and controlling access.
- **NAT Gateway**: Allows instances in the private subnet to initiate outbound traffic to the internet.
- **Route Tables**: For public and private subnets to control network routing.
- **EKS Cluster**: Kubernetes cluster managed by AWS EKS.
- **EKS Node Groups**: Linux and Windows node groups for the EKS cluster.
- **IAM Roles**: Roles with necessary policies for EKS and EC2 instances.
- **RDS SQL Server Instance**: A relational database instance for data persistence.
- **Security Groups**: For EKS cluster and Ingress controller.

## Usage

To deploy this template:

1. **Upload the template to AWS CloudFormation**:
   You can upload this template to AWS CloudFormation through the AWS Management Console, AWS CLI, or AWS CloudFormation APIs.

2. **Fill in the Parameters**:
   Some resources, like the RDS SQL Server instance, require specific parameters (e.g., `MasterUsername`, `MasterUserPassword`). Ensure these values are set before deployment.

3. **Execute the Stack**:
   Once uploaded and parameters are set, execute the stack to create the resources.

4. **Monitor the Stack Creation**:
   Monitor the progress in the AWS CloudFormation console. Upon successful completion, all resources will be deployed.

## Customization

- **Certificate Management**:
  This template does not include an AWS Certificate Manager (ACM) resource. Users are free to integrate their preferred SSL/TLS certificate provider, such as Let's Encrypt, as per their requirements.

- **Kubernetes Configuration**:
  Further Kubernetes-specific configurations (like deploying workloads, setting up ingress controllers, etc.) are to be done post-deployment within the EKS cluster.

## Outputs

The template provides several outputs for easy reference to created resources:

- `EKSClusterArn`: The ARN of the created EKS Cluster.
- `PublicSubnetId`: The ID of the public subnet.
- `PrivateSubnetId`: The ID of the first private subnet.
- `PrivateSubnet2Id`: The ID of the second private subnet.
- `RDSInstanceEndpoint`: The endpoint address of the RDS instance.

## Important Notes

- **Security**: Ensure that the `MasterUserPassword` for the RDS instance is secured and rotated regularly.
- **Costs**: Deploying this template will create AWS resources that might incur costs. Please check the AWS pricing page for details.
- **Region**: Before deployment, ensure that all services and resources are available in your AWS region.