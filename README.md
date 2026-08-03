# AWS Kubernetes Bootstrap
The `terraform-aws-kubernetes-bootstrap` module simplifies private bootstrapping of EKS clusters.  
The module uses a serverless AWS Lambda function to configure the Kubernetes cluster and install Helm charts.  
The Lambda is deployed inside the EKS VPC, allowing it to access the Kubernetes API without exposing it publicly. 

### Features
* Deploys a Lambda function inside the EKS VPC
* Supports private access to the Kubernetes API
* Authenticates to EKS using AWS IAM
* Installs and manages Helm charts
* Keeps Kubernetes bootstrap operations within AWS

### How it works
Terraform creates the Lambda function and required IAM and security group configuration.  
After deployment, Terraform invokes the function with the configured Helm charts.

![Architecture](https://raw.githubusercontent.com/im1xy/terraform-aws-kubernetes-bootstrap/main/docs/images/architecture.png)

The Lambda function:
1. Retrieves the EKS cluster configuration.
2. Generates an EKS authentication token.
3. Configures a temporary kubeconfig.
4. Connects to the Kubernetes API.
5. Installs the configured Helm charts.

This makes it possible to provision and bootstrap private EKS clusters entirely through Terraform, without exposing the Kubernetes API publicly or requiring the Terraform execution environment to have network access to the cluster.

### Prerequisites
The following tools must be installed in the environment running Terraform.  
They are used to build and package the Lambda deployment artifact:
- `zip`
- `tar`
- `curl`
- `pip3`
- `python3`

### Example
Below is a basic example of how to use the module to install the `metrics-server` Helm chart.
```hcl
module "bootstrap" {
  source = "im1xy/kubernetes-bootstrap/aws"
  version = "1.0.0"

  cluster = aws_eks_cluster.this
  charts = {
    metrics-server = {
      chart      = "metrics-server"
      repository = "https://kubernetes-sigs.github.io/metrics-server"
      namespace  = "monitoring"
      values = {
        resources = {
          requests = {
            cpu    = "100m"
            memory = "200Mi"
          }
          limits = {
            cpu    = "100m"
            memory = "200Mi"
          }
        }
      }
    }
  }
}
```
