variable "project_id" { type = string }     # 대상 프로젝트
variable "location" { type = string }       # 리전 (예: asia-northeast3)
variable "repository_id" { type = string }  # 리포지토리 이름
variable "format" {
  type    = string
  default = "DOCKER"
}

resource "google_artifact_registry_repository" "this" {
  # GKE에서 사용할 컨테이너 이미지를 저장하는 Regional Artifact Registry
  location      = var.location
  project       = var.project_id
  repository_id = var.repository_id
  format        = var.format
  description   = "Container images for GKE workloads"
}

output "repository" {
  value = google_artifact_registry_repository.this.repository_id # 편의 출력
}
