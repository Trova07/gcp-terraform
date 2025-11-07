variable "network_name" { type = string }
variable "auto_create_subnetworks" { type = bool }
variable "subnet_configs" {
  description = "List of subnet objects: name, ip_cidr_range, region, optional secondary_ip_ranges"
  type = list(object({
    name                  = string
    ip_cidr_range         = string
    region                = string
    secondary_ip_ranges   = optional(list(object({
      range_name    = string
      ip_cidr_range = string
    })), [])
  }))
}

resource "google_compute_network" "vpc" {
  name                    = var.network_name
  auto_create_subnetworks = var.auto_create_subnetworks
}

resource "google_compute_subnetwork" "subnets" {
  for_each                 = { for s in var.subnet_configs : s.name => s }
  name                     = each.value.name
  ip_cidr_range            = each.value.ip_cidr_range
  region                   = each.value.region
  network                  = google_compute_network.vpc.id
  private_ip_google_access = true

  dynamic "secondary_ip_range" {
    for_each = each.value.secondary_ip_ranges
    content {
      range_name    = secondary_ip_range.value.range_name
      ip_cidr_range = secondary_ip_range.value.ip_cidr_range
    }
  }
}

output "vpc_self_link" { value = google_compute_network.vpc.self_link }
output "subnet_self_links" { value = [for s in google_compute_subnetwork.subnets : s.self_link] }
output "subnets_map" {
  description = "Map of subnet name to attributes"
  value = {
    for name, s in google_compute_subnetwork.subnets : name => {
      self_link = s.self_link
      name      = s.name
      region    = s.region
    }
  }
}
