variable "network_name" { type = string }              # VPC 이름
variable "auto_create_subnetworks" { type = bool }      # 기본 서브넷 자동 생성 여부
variable "subnet_configs" {                             # 세컨더리 대역을 지원하는 사용자 정의 서브넷 목록
  description = "서브넷 객체 리스트: name, ip_cidr_range, region, optional secondary_ip_ranges"
  type = list(object({
    name                  = string
    ip_cidr_range         = string
    region                = string
  secondary_ip_ranges   = optional(list(object({      # GKE 파드/서비스 IP Alias용 세컨더리 대역
      range_name    = string
      ip_cidr_range = string
    })), [])
  }))
}

resource "google_compute_network" "vpc" {
  name                    = var.network_name
  auto_create_subnetworks = var.auto_create_subnetworks # false 권장: 프로덕션에서 수동 관리
}

resource "google_compute_subnetwork" "subnets" {
  for_each                 = { for s in var.subnet_configs : s.name => s } # 정의된 서브넷 반복 생성
  name                     = each.value.name
  ip_cidr_range            = each.value.ip_cidr_range
  region                   = each.value.region
  network                  = google_compute_network.vpc.id
  private_ip_google_access = true # 퍼블릭 IP 없이 Google API 접근 허용

  dynamic "secondary_ip_range" {                         # GKE IP Alias용 세컨더리 대역 부착
    for_each = each.value.secondary_ip_ranges
    content {
      range_name    = secondary_ip_range.value.range_name
      ip_cidr_range = secondary_ip_range.value.ip_cidr_range
    }
  }
}

output "vpc_self_link" { value = google_compute_network.vpc.self_link }                 # 다른 모듈 참조용
output "subnet_self_links" { value = [for s in google_compute_subnetwork.subnets : s.self_link] } # 서브넷 리스트
output "subnets_map" {                                                                  # 다른 모듈에서 조회하기 위한 맵
  description = "서브넷 이름 -> 속성 매핑"
  value = {
    for name, s in google_compute_subnetwork.subnets : name => {
      self_link = s.self_link
      name      = s.name
      region    = s.region
    }
  }
}
