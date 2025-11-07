variable "project_id" { type = string }
variable "location" { type = string }
variable "repository_id" { type = string }
variable "format" {
  type    = string
  default = "DOCKER"
}

resource "google_artifact_registry_repository" "this" {
  location      = var.location
  project       = var.project_id
  repository_id = var.repository_id
  format        = var.format
  description   = "Container images for GKE workloads"
}

output "repository" {
  value = google_artifact_registry_repository.this.repository_id
}
