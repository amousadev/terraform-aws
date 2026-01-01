terraform {
  # Recommended for 2026 to ensure support for latest OIDC & EKS features
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      # Use ~> 5.0 if your code is established. 
      # Use ~> 6.0 ONLY if you have updated your S3 and IAM syntax.
      version = "~> 5.0" 
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.15"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
  }
}

provider "aws" { region = "us-east-1" }

# Why: We need the Helm provider to install Cilium, ArgoCD, and ESO
provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
      command     = "aws"
    }
  }
}