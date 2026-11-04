resource "helm_release" "argocd" {
    name = "argocd"
    namespace = "argocd"
    create_namespace = true
    repository = "https://argoproj.github.io/argo-helm"
    chart = "argo-cd"
    version ="10.11.6"
    timeout = 600
    depends_on = [ module.eks ]

    values = [yamlencode({
        configs = {
            repositories = {
                "idp-infra" = {
                    url = "https://github.com/wesley-codes/idp-infra.git"
                    username = "wesley-codes"
                    type = "git"
                }
            }
        }
    })]
    set_sensitive = [ {
      name = "configs.repositories.idp-infra.password"
      value = var.github_token
    } ]
}