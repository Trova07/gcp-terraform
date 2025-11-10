terraform {
  # Terraform 코어 버전 요구사항 (낮은 버전에서의 호환성 문제 방지)
  required_version = ">= 1.6.0"
  required_providers {
    google = {
      # GCP 리소스를 위한 HashiCorp Google 프로바이더
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}

provider "google" {
  # 모든 리소스에 공통으로 적용될 프로젝트/리전/존 범위 설정
  project = var.project_id
  region  = var.region
  zone    = var.zone
  # 조건부 자격증명: 키 파일 경로가 있으면 사용, 없으면 ADC(Application Default Credentials) 사용
  credentials = var.credentials_file != "" ? file(var.credentials_file) : null
}

# 리소스 생성 시 403/404 오류를 방지하기 위해 필요한 Google API를 선제적으로 활성화
resource "google_project_service" "enabled" {
  for_each           = toset(var.enable_apis)  # 활성화할 API 서비스 이름 리스트 반복
  project            = var.project_id
  service            = each.value             # API 이름 (예: compute.googleapis.com)
  disable_on_destroy = false                  # Terraform destroy 후에도 API 비활성화하지 않음
}

module "network" {
  source                  = "./modules/network"
  network_name            = var.vpc_name
  auto_create_subnetworks = false   # 기본 서브넷 자동 생성 비활성화(수동 관리 권장)
  # GKE 파드/서비스 IP Alias를 위한 기본 서브넷 + 세컨더리 대역 설정
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
  # 예시 버킷(상태 또는 아티팩트 보관 용도) - 실제 Terraform backend 설정은 별도 backend.tf 사용
  name          = var.state_bucket_name
  location      = var.region
  force_destroy = false                   # 실수로 객체까지 삭제되는 것을 방지(명시적으로만 삭제)
  uniform_bucket_level_access = true      # 객체 ACL 대신 IAM만 사용(권장)
  versioning { enabled = true }           # 복구를 위한 버전 보관
  lifecycle_rule {                        # 보존 정책: 365일 경과 객체 삭제
    action { type = "Delete" }
    condition { age = 365 }
  }
  depends_on = [google_project_service.enabled]
}

resource "google_service_account" "terraform" {
  # Terraform 자동화(CI/CD 또는 로컬 임퍼서네이션) 전용 서비스 계정
  account_id   = var.tf_sa_id
  display_name = "Terraform Automation"
}

resource "google_project_iam_binding" "tf_sa_storage_admin" {
  # Terraform SA에 storage.admin 부여(버킷/오브젝트 관리). 필요 시 최소 권한으로 점진 축소 권장
  project    = var.project_id
  role       = "roles/storage.admin"
  members    = ["serviceAccount:${google_service_account.terraform.email}"]
  depends_on = [google_project_service.enabled]
}

resource "google_project_iam_binding" "tf_sa_compute_viewer" {
  # Terraform SA에 Compute 읽기 권한 부여(인스턴스/네트워크 조회 등)
  project    = var.project_id
  role       = "roles/compute.viewer"
  members    = ["serviceAccount:${google_service_account.terraform.email}"]
  depends_on = [google_project_service.enabled]
}

output "tf_service_account_email" {
  # CI/CD 또는 크로스 프로젝트 IAM 바인딩에서 활용할 이메일 출력
  value = google_service_account.terraform.email
}

# Cloud NAT for private workloads outbound internet access
module "nat" {
  # 프라이빗 노드의 아웃바운드 인터넷 접근을 위한 Cloud Router + NAT (예: 컨테이너 이미지 Pull)
  source      = "./modules/nat"
  project_id  = var.project_id
  region      = var.region
  router_name = "router-${var.region}"
  nat_name    = "nat-${var.region}"
  network     = module.network.vpc_self_link
  depends_on  = [google_project_service.enabled]
}

# GKE Private Standard cluster with IP alias and Workload Identity
module "gke" {
  # IP Alias/Workload Identity를 사용하는 Private GKE Standard 클러스터 (egress는 NAT에 의존)
  source                        = "./modules/gke"
  project_id                    = var.project_id
  region                        = var.region
  cluster_name                  = var.cluster_name
  network                       = module.network.vpc_self_link
  subnetwork                    = var.primary_subnet_name
  pods_secondary_range_name     = var.pods_secondary_range_name
  services_secondary_range_name = var.services_secondary_range_name
  depends_on                    = [module.nat]
}

# Artifact Registry for container images
module "artifact_registry" {
  # GKE 워크로드의 컨테이너 이미지를 저장/스캔하기 위한 Artifact Registry 리포지토리
  source        = "./modules/artifact_registry"
  project_id    = var.project_id
  location      = var.region
  repository_id = var.artifact_registry_repo
  depends_on    = [google_project_service.enabled]
}
