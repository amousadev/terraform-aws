# 1. Install External Secrets Operator (ESO)
resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  namespace        = "external-secrets"
  create_namespace = true
  
  set { name = "installCRDs"; value = "true" }
}

# 2. Define the Policy: "Can Read Secrets"
resource "aws_iam_policy" "secrets_read_policy" {
  name        = "EKSSecretsReadPolicy"
  description = "Allows reading secrets from Secrets Manager"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
      Resource = "*" # In prod, restrict this to specific ARNs
    }]
  })
}

# 3. Create the Role and Associate it with EKS (IRSA)
module "secrets_iam_role" {
  source    = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  role_name = "eks-secrets-reader-role"

  role_policy_arns = { policy = aws_iam_policy.secrets_read_policy.arn }

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["default:app-service-account"]
    }
  }
}

# 4. Output the Role ARN (We need this for the Helm Chart)
output "secrets_role_arn" {
  value = module.secrets_iam_role.iam_role_arn
}