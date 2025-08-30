# kubeflow_automation

This repository provides a complete, automated, and reproducible MLOps environment on Google Cloud Platform (GCP). It uses Terraform to provision a Google Kubernetes Engine (GKE) cluster and ArgoCD for GitOps-based deployment of Kubeflow and its dependencies.

The entire lifecycle of the environment, from creation to destruction, is managed via GitHub Actions, making it easy to spin up for experiments and tear down to save costs.

## Architecture

1.  **Infrastructure (Terraform)**: Provisions a GKE cluster on GCP.
2.  **Bootstrap (Terraform)**: Installs ArgoCD onto the GKE cluster.
3.  **Application Delivery (ArgoCD)**: ArgoCD takes over and deploys the full Kubeflow stack (including Istio) by tracking the manifests in the `kubernetes-manifests` directory of this repository.
4.  **Automation (GitHub Actions)**: Provides workflows to `apply` or `destroy` the entire stack.

## Prerequisites

1.  A GitHub Account.
2.  A Google Cloud Platform (GCP) Account with a project and billing enabled.
3.  The `gcloud` command-line tool installed and authenticated to your GCP account.

## Setup Instructions

Follow these steps to configure your environment.

### 1. Fork the Repository

Fork this repository into your own GitHub account. All GitHub Actions will run from your fork.

### 2. Configure GCP Project

Choose a GCP project or create a new one. Set it as your default project in `gcloud`:

```sh
gcloud config set project YOUR_PROJECT_ID
```

Enable the necessary APIs for Terraform to work:

```sh
gcloud services enable \
  iam.googleapis.com \
  container.googleapis.com \
  compute.googleapis.com \
  iamcredentials.googleapis.com \
  cloudresourcemanager.googleapis.com
```

### 3. Create a GCP Service Account for Terraform

This service account will be used by GitHub Actions to provision resources.

```sh
# Create the service account
gcloud iam service-accounts create terraform-deployer \
  --display-name="Terraform Deployer SA"

# Grant it the necessary permissions
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:terraform-deployer@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/owner" # For simplicity; you can scope this down in production
```

### 4. Set up Workload Identity Federation

This is the secure, recommended way to allow GitHub Actions to authenticate to GCP without using long-lived keys.

```sh
# Enable Workload Identity Federation
gcloud iam workload-identity-pools create "github-pool" \
  --location="global" \
  --display-name="GitHub Actions Pool"

# Get the full ID of the pool
WORKLOAD_IDENTITY_POOL_ID=$(gcloud iam workload-identity-pools describe "github-pool" --location="global" --format="value(name)")

# Create a provider for the pool that trusts your GitHub repository
gcloud iam workload-identity-pools providers create-oidc "github-provider" \
  --workload-identity-pool="github-pool" \
  --location="global" \
  --issuer-uri="https://token.actions.githubusercontent.com" \
  --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository"

# Allow the service account to be impersonated by identities from your repo
gcloud iam service-accounts add-iam-policy-binding "terraform-deployer@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/${WORKLOAD_IDENTITY_POOL_ID}/attribute.repository/YOUR_GITHUB_USERNAME/kubeflow_automation"
```

### 5. Create GitHub Repository Secrets

In your forked GitHub repository, go to `Settings > Secrets and variables > Actions` and create the following secrets:

*   `GCP_PROJECT_ID`: Your Google Cloud project ID.
*   `GCP_SERVICE_ACCOUNT`: The full email of the service account you created (e.g., `terraform-deployer@your-project-id.iam.gserviceaccount.com`).
*   `GCP_WORKLOAD_IDENTITY_PROVIDER`: The full path of the Workload Identity Provider. You can get this with:
    ```sh
    echo "projects/YOUR_PROJECT_NUMBER/locations/global/workloadIdentityPools/github-pool/providers/github-provider"
    # Replace YOUR_PROJECT_NUMBER with the number of your GCP project.
    ```

## How to Run

### Deploy the MLOps Stack

1.  Go to the **Actions** tab in your forked repository.
2.  In the left sidebar, click on the **Terraform MLOps Stack Apply** workflow.
3.  Click the **Run workflow** dropdown, select the branch, and click **Run workflow**.
4.  The action will now run, provision the GKE cluster, and deploy the full stack. You can monitor the progress in the Actions log.

### Destroy the MLOps Stack

To avoid incurring costs, you can easily tear down all created resources.

1.  Go to the **Actions** tab.
2.  Click on the **Terraform MLOps Stack Destroy** workflow.
3.  Click **Run workflow** to start the destruction process.

## Accessing the Environment

After the `apply` workflow succeeds, the output logs will contain commands to:
1.  Configure `kubectl` to connect to your new GKE cluster.
2.  Retrieve the initial admin password for the ArgoCD UI.
3.  Port-forward to the Kubeflow dashboard, allowing you to access it at `http://localhost:8080`.