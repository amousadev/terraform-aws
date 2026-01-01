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
# NOTE: Prefer narrowly-scoped Resource ARNs where possible instead of "*".
#       Use variables for account-specific ARNs (e.g., CodeStar connection) to
#       avoid hardcoding across environments.
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
  # EXPLAIN: Use official submodule `iam-role-for-service-accounts` which
  #          provides IRSA (IAM Role for Service Accounts) behavior.
  #          The previous path with `-eks` is not present in the upstream
  #          module; using the correct submodule avoids source errors.
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"

  # EXPLAIN: The submodule expects `name` not `role_name`.
  name = "eks-secrets-reader-role"

  # EXPLAIN: Attach the created IAM policy via the `policies` map so the
  #          module will reference the correct ARN and manage attachments.
  policies = {
    EKSResourceAccessPolicy = aws_iam_policy.eks_resource_policy.arn
  }

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      # EXPLAIN: `namespace:serviceaccount` must match the Kubernetes SA used
      #          by the workload. Ensure `default:app-service-account` exists.
      namespace_service_accounts = ["default:app-service-account"]
    }
  }
}

# 4. [NEW] Role for ArgoCD Repo Server (ArgoCD-Repo-Server) 🤖
module "argocd_repo_role" {
  # EXPLAIN: Same submodule used for ArgoCD repo-server IRSA role. Keep
  #          naming and inputs consistent with the upstream module to avoid
  #          unexpected type/arg validation errors.
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"

  # EXPLAIN: Use `name` instead of `role_name` to match module variable.
  name = "argocd-repo-server-role"

  # EXPLAIN: Attach the combined policy via `policies` map. If ArgoCD only
  #          needs a subset, create a more restrictive policy instead.
  policies = {
    EKSResourceAccessPolicy = aws_iam_policy.eks_resource_policy.arn
  }

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      # EXPLAIN: Ensure the Kubernetes SA `argocd:argocd-repo-server` exists
      #          and the namespace/serviceaccount matches your ArgoCD install.
      namespace_service_accounts = ["argocd:argocd-repo-server"]
    }
  }
}

output "secrets_role_arn" {
  # EXPLAIN: The submodule exposes `arn` as an output. Use that instead of
  #          non-existent `iam_role_arn` to avoid output errors.
  value = module.secrets_iam_role.arn
}

output "argocd_role_arn" {
  # EXPLAIN: Same rationale as above for the ArgoCD role.
  value = module.argocd_repo_role.arn
}