variable "cluster_name" { type = string }
variable "project_id" { type = string }
variable "region" { type = string }
variable "network" { type = string } # VPC self link
variable "subnetwork" { type = string } # Subnet name
variable "pods_secondary_range_name" { type = string }
variable "services_secondary_range_name" { type = string }
variable "release_channel" {
  type    = string
  default = "REGULAR"
}
variable "master_ipv4_cidr" {
  type    = string
  default = "172.16.0.0/28"
}

resource "google_container_cluster" "this" {
  name                      = var.cluster_name
  project                   = var.project_id
  location                  = var.region
  network                   = var.network
  subnetwork                = var.subnetwork
  remove_default_node_pool  = true
  initial_node_count        = 1

  release_channel {
    channel = var.release_channel
  }

  networking_mode = "VPC_NATIVE"
  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_secondary_range_name
    services_secondary_range_name = var.services_secondary_range_name
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = var.master_ipv4_cidr
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS", "APISERVER", "SCHEDULER", "CONTROLLER_MANAGER"]
    managed_prometheus { enabled = true }
  }

  addons_config {
    http_load_balancing { disabled = false }
    horizontal_pod_autoscaling { disabled = false }
  }

  lifecycle {
    ignore_changes = [initial_node_count]
  }
}

resource "google_container_node_pool" "default" {
  name       = "default-pool"
  project    = var.project_id
  location   = var.region
  cluster    = google_container_cluster.this.name

  node_config {
    machine_type = "e2-standard-4"
    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
    workload_metadata_config {
      mode = "GKE_METADATA"
    }
    labels = {
      role = "app"
    }
    tags = ["gke-node"]
  }

  autoscaling {
    min_node_count = 1
    max_node_count = 4
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}

output "name" { value = google_container_cluster.this.name }
output "endpoint" { value = google_container_cluster.this.endpoint }
output "ca_certificate" { value = google_container_cluster.this.master_auth[0].cluster_ca_certificate }
