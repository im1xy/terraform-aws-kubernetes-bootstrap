provider "aws" {
  region = "us-east-1"
}

module "basic" {
  source = "../../"

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
