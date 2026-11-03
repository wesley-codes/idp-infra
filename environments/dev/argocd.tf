resource "helm_release" "argocd" {
    name = "argocd"
    namespace = "argocd"
    create_namespace = true
    repository = "https://argoproj.github.io/argo-helm"
    chart = "argo-cd"
    version ="10.11.6"
    timeout = 600
    depends_on = [ module.eks ]
}