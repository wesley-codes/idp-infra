resource "helm_release" "root_app" {
  name = "argocd-apps"
  namespace = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart = "argocd-apps"
  version = "2.0.7"
  depends_on = [helm_release.argocd]

  values = [yamlencode({
    applications = {
        root = merge(
            { namespace = "argocd"},
            yamldecode(file("${path.module}/../../gitops/bootstrap/root-app.yaml")).spec
        )
    }
  })]
}