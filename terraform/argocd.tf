resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true

  # EXPLAIN: Attach the IAM role to ArgoCD's repo-server service account.
  #          This enables IRSA (IAM Roles for Service Accounts) so the repo-server
  #          can authenticate to GitHub using AWS CodeConnections without storing
  #          secrets in Kubernetes.
  set {
    name  = "repoServer.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    # EXPLAIN: Reference the ARN output from the argocd_repo_role module.
    #          The module exposes 'arn' as an output, not 'iam_role_arn'.
    value = module.argocd_repo_role.arn
  }

  # EXPLAIN: Configure ArgoCD to use AWS credentials for HTTPS GitHub URLs.
  #          This tells ArgoCD to leverage the attached IAM role for GitHub auth
  #          via CodeConnections, avoiding manual token management.
  set {
    name  = "configs.cm.github.creds.https"
    value = "aws"
  }
}

# EXPLAIN: Create an ArgoCD Application resource that points to the Helm chart
#          in the Git repo. This automates deployment of the app to the cluster.
#          The 'depends_on' ensures ArgoCD is installed first.
resource "kubernetes_manifest" "root_app" {
  depends_on = [helm_release.argocd]
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata   = { name = "production-app", namespace = "argocd" }
    spec = {
      source = {
        # EXPLAIN: Use HTTPS URL for the repo; ArgoCD will use the IAM role
        #          to authenticate via AWS CodeConnections.
        repoURL = "https://github.com/amousadev/terraform-aws"
        path    = "my-app-chart"
      }
      destination = { server = "https://kubernetes.default.svc", namespace = "default" }
      # EXPLAIN: Enable automated sync with self-healing and pruning to keep
      #          the cluster state in sync with the repo.
      syncPolicy  = { automated = { selfHeal = true, prune = true } }
    }
  }
}