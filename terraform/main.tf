terraform {
  required_version = ">= 1.6.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
  credentials = var.credentials_file != "" ? file(var.credentials_file) : null
}

# Ensure required Google APIs are enabled before creating resources
resource "google_project_service" "enabled" {
  for_each           = toset(var.enable_apis)
  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

module "network" {
  source              = "./modules/network"
  network_name        = var.vpc_name
  auto_create_subnetworks = false
  subnet_configs = [
    {
      name          = var.primary_subnet_name
      ip_cidr_range = var.primary_subnet_cidr
      region        = var.region
      secondary_ip_ranges = [
        { range_name = var.pods_secondary_range_name,     ip_cidr_range = var.pods_secondary_cidr },
        { range_name = var.services_secondary_range_name, ip_cidr_range = var.services_secondary_cidr }
      ]
    }
  ]
  depends_on = [google_project_service.enabled]
}

resource "google_storage_bucket" "tf_state" {
  name          = var.state_bucket_name
  location      = var.region
  force_destroy = false
  uniform_bucket_level_access = true
  versioning { enabled = true }
  lifecycle_rule {
    action { type = "Delete" }
    condition { age = 365 }
  }
  depends_on = [google_project_service.enabled]
}

resource "google_service_account" "terraform" {
  account_id   = var.tf_sa_id
  display_name = "Terraform Automation"
}

resource "google_project_iam_binding" "tf_sa_storage_admin" {
  project = var.project_id
  role    = "roles/storage.admin"
  members = ["serviceAccount:${google_service_account.terraform.email}"]
  depends_on = [google_project_service.enabled]
}

resource "google_project_iam_binding" "tf_sa_compute_viewer" {
  project = var.project_id
  role    = "roles/compute.viewer"
  members = ["serviceAccount:${google_service_account.terraform.email}"]
  depends_on = [google_project_service.enabled]
}

output "tf_service_account_email" {
  value = google_service_account.terraform.email
}

# Cloud NAT for private workloads outbound internet access
module "nat" {
  source     = "./modules/nat"
  project_id = var.project_id
  region     = var.region
  router_name = "router-${var.region}"
  nat_name    = "nat-${var.region}"
  network     = module.network.vpc_self_link
  depends_on  = [google_project_service.enabled]
}

# GKE Private Standard cluster with IP alias and Workload Identity
module "gke" {
  source                          = "./modules/gke"
  project_id                      = var.project_id
  region                          = var.region
  cluster_name                    = var.cluster_name
  network                         = module.network.vpc_self_link
  subnetwork                      = var.primary_subnet_name
  pods_secondary_range_name       = var.pods_secondary_range_name
  services_secondary_range_name   = var.services_secondary_range_name
  depends_on                      = [module.nat]
}

# Artifact Registry for container images
module "artifact_registry" {
  source        = "./modules/artifact_registry"
  project_id    = var.project_id
  location      = var.region
  repository_id = var.artifact_registry_repo
  depends_on    = [google_project_service.enabled]
}
