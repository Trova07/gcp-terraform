variable "project_id" { type = string }
variable "region" { type = string }
variable "router_name" { type = string }
variable "nat_name" { type = string }
variable "network" { type = string }

resource "google_compute_router" "this" {
  name    = var.router_name
  project = var.project_id
  region  = var.region
  network = var.network

  bgp {
    asn = 64514
  }
}

resource "google_compute_router_nat" "this" {
  name                               = var.nat_name
  project                            = var.project_id
  region                             = var.region
  router                             = google_compute_router.this.name
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  enable_endpoint_independent_mapping = true

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

output "nat_name" { value = google_compute_router_nat.this.name }
