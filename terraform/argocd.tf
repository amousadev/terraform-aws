resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true

  # [NEW] Attach the IAM role to the repo-server component
  set {
    name  = "repoServer.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.argocd_repo_role.iam_role_arn
  }

  # [NEW] Tell ArgoCD to use AWS credentials for GitHub HTTPS URLs
  set {
    name  = "configs.cm.github.creds.https"
    value = "aws"
  }
}

resource "kubernetes_manifest" "root_app" {
  depends_on = [helm_release.argocd]
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata   = { name = "production-app", namespace = "argocd" }
    spec = {
      source = {
        # [IMPORTANT] Must use HTTPS URL for CodeConnections
        repoURL = "https://github.com/amousadev/terraform-aws"
        path    = "my-app-chart"
      }
      destination = { server = "https://kubernetes.default.svc", namespace = "default" }
      syncPolicy  = { automated = { selfHeal = true, prune = true } }
    }
  }
}