variable "gcp_project_id" {
  description = "The GCP project ID to deploy resources into. This is set via GitHub secrets."
  type        = string
}

variable "gcp_region" {
  description = "The GCP region to deploy resources into."
  type        = string
  default     = "us-central1"
}

variable "gcp_zones" {
  description = "The GCP zones to deploy GKE nodes into."
  type        = list(string)
  default     = ["us-central1-a", "us-central1-b", "us-central1-c"]
}

variable "cluster_name" {
  description = "The name for the GKE cluster."
  type        = string
  default     = "kubeflow-mlops-cluster"
}

variable "machine_type" {
  description = "The machine type for the GKE nodes. Kubeflow requires a minimum of 4 vCPUs."
  type        = string
  default     = "e2-standard-4"
}

variable "min_node_count" {
  description = "The minimum number of nodes for the GKE cluster's default node pool."
  type        = number
  default     = 1
}

variable "max_node_count" {
  description = "The maximum number of nodes for the GKE cluster's default node pool for autoscaling."
  type        = number
  default     = 3
}

variable "repo_url" {
  description = "The URL of the GitHub repository containing the application manifests. This is set by the GitHub Action."
  type        = string
}

variable "repo_branch" {
  description = "The branch of the GitHub repository to sync from. This is set by the GitHub Action."
  type        = string
  default     = "main"
}