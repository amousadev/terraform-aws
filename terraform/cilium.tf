resource "helm_release" "cilium" {
  name       = "cilium"
  repository = "https://helm.cilium.io/"
  chart      = "cilium"
  namespace  = "kube-system"

  set { name = "eni.enabled"; value = "true" }
  set { name = "ipam.mode"; value = "eni" }
  set { name = "ingressController.enabled"; value = "true" }
  set { name = "ingressController.loadbalancerMode"; value = "dedicated" }
}