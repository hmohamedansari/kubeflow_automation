output "gke_cluster_name" {
  description = "The name of the GKE cluster."
  value       = module.gke.name
}

output "gke_cluster_endpoint" {
  description = "The endpoint of the GKE cluster."
  value       = module.gke.endpoint
  sensitive   = true
}

output "get_kubeconfig_command" {
  description = "Command to get kubeconfig for the cluster."
  value       = "gcloud container clusters get-credentials ${module.gke.name} --region ${module.gke.location} --project ${var.gcp_project_id}"
}

output "argocd_initial_password_command" {
  description = "Command to retrieve the initial admin password for ArgoCD."
  value       = "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
}

output "kubeflow_dashboard_access_command" {
  description = "Command to port-forward to the Kubeflow dashboard."
  value       = "echo 'Run this command and then open http://localhost:8080 in your browser:' && kubectl port-forward -n istio-system svc/istio-ingressgateway 8080:80"
}

data "kubernetes_secret" "argocd_initial_admin_secret" {
  # This data source depends on the ArgoCD installation.
  # It allows us to fetch the secret's value if needed, though we output the command for better UX.
  depends_on = [kubectl_manifest.argocd_install]

  metadata {
    name      = "argocd-initial-admin-secret"
    namespace = "argocd"
  }
}

output "argocd_initial_password" {
  description = "Initial password for the ArgoCD 'admin' user."
  value       = base64decode(data.kubernetes_secret.argocd_initial_admin_secret.data["password"])
  sensitive   = true
}