output "vpc_self_link" {
  value = module.network.vpc_self_link
}

output "subnet_self_links" {
  value = module.network.subnet_self_links
}

output "state_bucket_name" {
  value = google_storage_bucket.tf_state.name
}

output "gke_cluster_name" {
  value = module.gke.name
}

output "artifact_registry_repo" {
  value = module.artifact_registry.repository
}
