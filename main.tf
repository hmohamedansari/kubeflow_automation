##################################################################################
# GCP Project Services
##################################################################################

resource "google_project_service" "compute" {
  project = var.gcp_project_id
  service = "compute.googleapis.com"
}

resource "google_project_service" "container" {
  project = var.gcp_project_id
  service = "container.googleapis.com"
}

resource "google_project_service" "iam" {
  project = var.gcp_project_id
  service = "iam.googleapis.com"
}

##################################################################################
# GKE Cluster
##################################################################################

module "gke" {
  source                     = "terraform-google-modules/kubernetes-engine/google"
  version                    = "30.1.0"
  project_id                 = var.gcp_project_id
  name                       = var.cluster_name
  region                     = var.gcp_region
  zones                      = var.gcp_zones
  network                    = var.cluster_name
  subnetwork                 = var.cluster_name
  ip_range_pods              = "${var.cluster_name}-pods"
  ip_range_services          = "${var.cluster_name}-services"
  remove_default_node_pool   = true
  initial_node_count         = 1
  http_load_balancing        = true
  horizontal_pod_autoscaling = true
  create_service_account     = false # We recommend creating the SA outside the module
  identity_namespace         = "${var.gcp_project_id}.svc.id.goog"

  node_pools = [
    {
      name           = "default-pool"
      machine_type   = var.machine_type
      node_locations = join(",", var.gcp_zones)
      min_count      = var.min_node_count
      max_count      = var.max_node_count
      auto_repair    = true
      auto_upgrade   = true
    },
  ]

  depends_on = [
    google_project_service.compute,
    google_project_service.container
  ]
}

##################################################################################
# Kubernetes Provider and Application Bootstrap
##################################################################################

data "google_client_config" "default" {}

provider "kubernetes" {
  host                   = "https://kuberne.tes" # Workaround for initial plan
  token                  = "dummy"               # Workaround for initial plan
  cluster_ca_certificate = "dummy"               # Workaround for initial plan

  # The provider is configured dynamically using the GKE module outputs
  # during the apply phase.
  host                   = "https://${module.gke.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(module.gke.ca_certificate)
}

provider "kubectl" {
  host                   = "https://kuberne.tes" # Workaround for initial plan
  token                  = "dummy"               # Workaround for initial plan
  cluster_ca_certificate = "dummy"               # Workaround for initial plan
  load_config_file       = false

  host                   = "https://${module.gke.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(module.gke.ca_certificate)
}

# Install ArgoCD from the official manifest
data "http" "argocd_install" {
  url = "https://raw.githubusercontent.com/argoproj/argo-cd/v2.11.2/manifests/install.yaml"
}

resource "kubectl_manifest" "argocd_install" {
  yaml_body  = data.http.argocd_install.response_body
  depends_on = [module.gke]
}

# Template the ArgoCD application manifest with the correct repo URL and branch
data "template_file" "argocd_app" {
  template = file("${path.module}/../kubernetes-manifests/argocd/application.yaml")
  vars = {
    REPO_URL    = var.repo_url
    REPO_BRANCH = var.repo_branch
  }
}

# Apply the root ArgoCD application to kickstart the GitOps process
resource "kubectl_manifest" "argocd_root_app" {
  yaml_body = data.template_file.argocd_app.rendered
  depends_on = [
    kubectl_manifest.argocd_install
  ]
}