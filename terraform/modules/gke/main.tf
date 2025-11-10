variable "cluster_name" { type = string }                   # GKE 클러스터 이름
variable "project_id" { type = string }                    # 대상 프로젝트
variable "region" { type = string }                        # 리전(Regional 클러스터 위치)
variable "network" { type = string } # VPC self link       # VPC 참조
variable "subnetwork" { type = string } # Subnet name      # 서브넷 이름
variable "pods_secondary_range_name" { type = string }     # 파드용 세컨더리 대역 이름
variable "services_secondary_range_name" { type = string } # 서비스용 세컨더리 대역 이름
variable "release_channel" {
  type    = string
  default = "REGULAR"
}
variable "master_ipv4_cidr" {
  type    = string
  default = "172.16.0.0/28"
}

resource "google_container_cluster" "this" {
  # IP Alias 및 Managed Prometheus가 활성화된 Regional Private GKE Standard 클러스터
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

  networking_mode = "VPC_NATIVE" # IP Alias 사용을 위해 필수
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
  # 오토스케일링·머신 타입 제어를 위해 분리 관리되는 기본 노드 풀
  name       = "default-pool"
  project    = var.project_id
  location   = var.region
  cluster    = google_container_cluster.this.name

  node_config {
    machine_type = "e2-standard-4"
    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"] # 범위가 넓음 → 세밀 권한은 Workload Identity 권장
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

output "name" { value = google_container_cluster.this.name }                            # 클러스터 이름
output "endpoint" { value = google_container_cluster.this.endpoint }                    # API 서버 엔드포인트
output "ca_certificate" { value = google_container_cluster.this.master_auth[0].cluster_ca_certificate } # kubeconfig 구성용
