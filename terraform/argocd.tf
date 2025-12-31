resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
}

resource "kubernetes_manifest" "root_app" {
  depends_on = [helm_release.argocd]
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata   = { name = "production-app", namespace = "argocd" }
    spec = {
      source = {
        repoURL = "https://github.com/YOUR_USER/YOUR_REPO.git"
        path    = "my-app-chart"
      }
      destination = { server = "https://kubernetes.default.svc", namespace = "default" }
      syncPolicy  = { automated = { selfHeal = true, prune = true } }
    }
  }
}