variable "project_id" { type = string }   # 대상 프로젝트
variable "region" { type = string }       # 라우터/NAT 리전
variable "router_name" { type = string }  # Cloud Router 이름
variable "nat_name" { type = string }     # NAT 이름
variable "network" { type = string }      # VPC self link

resource "google_compute_router" "this" {
  name    = var.router_name
  project = var.project_id
  region  = var.region
  network = var.network

  bgp {                   # 최소 BGP 설정; 하이브리드 피어링 시 ASN 조정 가능
    asn = 64514
  }
}

resource "google_compute_router_nat" "this" {
  name                               = var.nat_name
  project                            = var.project_id
  region                             = var.region
  router                             = google_compute_router.this.name
  nat_ip_allocate_option             = "AUTO_ONLY"                     # NAT 외부 IP 자동 할당
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES" # 모든 서브넷 포함
  enable_endpoint_independent_mapping = true                            # 연결 안정성 향상

  log_config {
    enable = true
    filter = "ERRORS_ONLY"  # 트러블슈팅 시 ALL로 변경 가능 (로그/비용 증가)
  }
}

output "nat_name" { value = google_compute_router_nat.this.name } # 진단용 출력
