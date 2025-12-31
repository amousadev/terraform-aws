# 1. Install External Secrets Operator (ESO)
resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  namespace        = "external-secrets"
  create_namespace = true
  set { name = "installCRDs"; value = "true" }
}

# 2. Define the Combined Policy: Secrets + GitHub Connection
resource "aws_iam_policy" "eks_resource_policy" {
  name        = "EKSResourceAccessPolicy"
  description = "Allows reading secrets and using GitHub connections"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
        Resource = "*" 
      },
      {
        # [NEW] Permission for ArgoCD to use the AWS connection
        Effect   = "Allow"
        Action   = ["codestar-connections:UseConnection", "codestar-connections:GetConnection"]
        Resource = "arn:aws:codeconnections:us-east-1:015932244900:connection/8568d5fa-96ad-462a-93c8-d30ae458a4ca" # Replace with specific Connection ARN for better security
      }
    ]
  })
}

# 3. Role for Application (App-Service-Account)
module "secrets_iam_role" {
  source    = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  role_name = "eks-secrets-reader-role"
  role_policy_arns = { policy = aws_iam_policy.eks_resource_policy.arn }
  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["default:app-service-account"]
    }
  }
}

# 4. [NEW] Role for ArgoCD Repo Server (ArgoCD-Repo-Server) 🤖
module "argocd_repo_role" {
  source    = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  role_name = "argocd-repo-server-role"
  role_policy_arns = { policy = aws_iam_policy.eks_resource_policy.arn }
  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["argocd:argocd-repo-server"]
    }
  }
}

output "secrets_role_arn" { value = module.secrets_iam_role.iam_role_arn }
output "argocd_role_arn" { value = module.argocd_repo_role.iam_role_arn }