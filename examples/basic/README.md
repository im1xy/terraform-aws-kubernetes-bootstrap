# Basic Bootstrap Example
This example demonstrates how to use the `terraform-aws-kubernetes-bootstrap` module to install Helm charts into an EKS cluster using an AWS Lambda function.

## Usage
```bash
terraform init
terraform plan
terraform apply
```

After the EKS cluster is created, the module invokes the Lambda function to connect to the Kubernetes API and install the configured Helm charts.

## Verification
```bash
aws eks --region us-east-1 update-kubeconfig --name example-cluster
kubectl get pods --all-namespaces
```

You should see the `metrics-server` pod running in the cluster.

## Cleanup
```bash
terraform destroy
```

Make sure to cleanup the Lambda function and any other resources created by the module to avoid incurring unnecessary costs.
