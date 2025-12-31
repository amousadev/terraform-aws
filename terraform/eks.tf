module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "prod-eks"
  cluster_version = "1.30"
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnets
  
  # Theory: Disable default Kube-Proxy so Cilium (eBPF) can take over
  cluster_addons = { 
    kube-proxy = { most_recent = true } 
    coredns    = { most_recent = true }
    vpc-cni    = { most_recent = true }
  }

  eks_managed_node_groups = {
    standard = {
      instance_types = ["t3.large"]
      min_size = 3
      max_size = 6
    }
  }
  
  # Theory: OIDC enables "IAM Roles for Service Accounts" (IRSA)
  # This allows the cluster to assume an IAM role to read secrets.
  enable_irsa = true
}