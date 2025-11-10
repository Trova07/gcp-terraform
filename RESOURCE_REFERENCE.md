# Terraform Resource Reference

최종 업데이트: 2025-11-10

루트 `terraform/main.tf` 및 `modules/*/main.tf` 내부에 정의된 주요 리소스들의 목적, 핵심 속성, 실무 주의사항을 한 곳에 정리했습니다.

---
## 목차
1. 루트 구성 (main.tf)
2. 네트워크 모듈 (modules/network/main.tf)
3. NAT 모듈 (modules/nat/main.tf)
4. GKE 모듈 (modules/gke/main.tf)
5. Artifact Registry 모듈 (modules/artifact_registry/main.tf)
6. Backend 설정 (backend.tf) 참고
7. 서비스 계정 & IAM 바인딩
8. 일반 주의사항 & 권장 패턴

---
## 1. 루트 구성 (`terraform/main.tf`)
### terraform 블록
- `required_version`: Terraform 최소 버전 고정으로 기능/호환 보장.
- `required_providers`: google provider 버전 제약(향후 브레이킹 업데이트 완화).

### provider "google"
- `project`, `region`, `zone`: 모든 하위 리소스 기본 스코프.
- `credentials`: 삼항 연산(`var.credentials_file != "" ? file(...) : null`)으로 키 파일 있으면 로드, 없으면 ADC 사용.
- 실무: 키 파일 대신 임퍼서네이션/Workload Identity Federation 권장.

### google_project_service "enabled"
- 목적: 필요한 API 사전 활성화(미활성시 403/404 에러 방지).
- `for_each`로 리스트 기반 자동 반복.
- `disable_on_destroy = false`: destroy 시 비활성화하지 않아 다른 팀 영향 최소화.

### module "network"
- VPC + Subnet + Secondary IP ranges(pods/services) 생성.
- `depends_on`: API 활성화 후 실행.
- 실무: Secondary range 이름은 GKE cluster에 정확히 매칭 필요.

### google_storage_bucket "tf_state"
- 예시 리소스(백엔드 버킷). 실제 backend는 `backend.tf`로 별도로 설정.
- `uniform_bucket_level_access = true`: IAM 기반 일원화.
- `versioning`, `lifecycle_rule`: 장기 보존/정리 정책.
- 실무: state 파일 버킷과 일반 아티팩트 버킷 분리 권장.

### google_service_account "terraform"
- Terraform automation 실행용 서비스 계정.
- 실무: 권한 최소화(필요한 역할만).

### IAM 바인딩 (storage.admin, compute.viewer)
- `google_project_iam_binding`: 동일 Role에 여러 멤버 세트. 여기선 하나만 포함.
- 실무: binding vs member 혼동 주의; 다른 TF 또는 콘솔 변경과 충돌 가능.

### module "nat"
- Cloud Router + NAT. Private 리소스 인터넷 접근(이미지 Pull 등) 보장.
- 실무: 로그 필터/모드 조정 가능. 비용/외부 접근 정책 점검.

### module "gke"
- Private Standard Cluster 구성.
- `depends_on = [module.nat]`: NAT 준비 후 클러스터 생성(이미지 Pull 오류 방지).

### module "artifact_registry"
- 컨테이너 이미지 저장소.
- 실무: 취약점 스캔 콘솔에서 활성화, 이미지 정리 정책 설정.

### outputs
- `tf_service_account_email`, 클러스터/레포 등은 별도 outputs.tf에 추가.

---
## 2. 네트워크 모듈 (`modules/network/main.tf`)
### 입력 변수
- `network_name`: VPC 이름.
- `auto_create_subnetworks`: 자동 기본 subnet 생성 여부(false 권장).
- `subnet_configs`: 사용자 정의 Subnet 리스트(Secondary ranges 포함).
  - `secondary_ip_ranges`: GKE IP Alias 용 cluster/services CIDR 정의.

### google_compute_network "vpc"
- 글로벌 VPC. AWS 대비 리전 스코프 아님.
- 실무: Shared VPC 확장 가능.

### google_compute_subnetwork "subnets"
- `for_each`로 다중 Subnet.
- `private_ip_google_access = true`: 프라이빗 Subnet에서 Google API 접근.
- `dynamic "secondary_ip_range"`: pods/services 이중 range 템플릿.

### outputs
- `vpc_self_link`, `subnet_self_links`, `subnets_map`: 다른 모듈 참조 편의.

주의:
- Secondary range 이름/크기 선정은 파드/서비스 수용량 고려.
- CIDR 겹침 방지.

---
## 3. NAT 모듈 (`modules/nat/main.tf`)
### google_compute_router "this"
- Cloud Router 생성. BGP ASN 기본값(64514) 지정.
- 실무: On-prem/하이브리드 라우팅 시 ASN 조정.

### google_compute_router_nat "this"
- NAT IP 자동 할당(AUTO_ONLY).
- `source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"`: 빠른 전체 적용.
- `enable_endpoint_independent_mapping`: 연결 안정성 향상.
- `log_config`: 오류만 로깅(ERRORS_ONLY) — 비용/로그량 조절.

주의:
- 과도한 NAT 세션/포트 고갈 모니터링 필요.
- 프리미엄 티어 비용 고려.

---
## 4. GKE 모듈 (`modules/gke/main.tf`)
### 변수들
- `cluster_name`, `project_id`, `region`, `network`, `subnetwork` 등 기본 필수.
- `pods_secondary_range_name`, `services_secondary_range_name`: IP Alias 매핑.
- `release_channel`: REGULAR/Stable/Rapid 선택.
- `master_ipv4_cidr`: private control plane CIDR.

### google_container_cluster "this"
- `remove_default_node_pool = true` 후 별도 node_pool 관리.
- `networking_mode = "VPC_NATIVE"`: IP Alias 필수.
- `ip_allocation_policy`: Secondary range 이름 연결.
- `private_cluster_config`: Private Nodes + Public Control Plane Endpoint only.
- `workload_identity_config`: Workload Identity 풀 활성화.
- `logging_config`, `monitoring_config`: 시스템/워크로드 로그 & Managed Prometheus 활성화.
- `addons_config`: HPA, HTTP LB.
- `lifecycle.ignore_changes`: 초기 노드 개수 변경 무시.

### google_container_node_pool "default"
- `machine_type`, autoscaling 범위.
- `oauth_scopes = ["cloud-platform"]`: 광범위 — 실무 최소 범위 또는 Workload Identity 집중 권장.
- `workload_metadata_config.mode = "GKE_METADATA"`: Workload Identity 전제.
- 라벨/태그: 운영/비용 태깅 용이.

### outputs
- `name`, `endpoint`, `ca_certificate`: kubectl 설정이나 다른 모듈 연계 시 활용.

주의:
- Private cluster: NAT/Firewall 준비 필수.
- Secondary ranges 정확히 대응하지 않으면 생성 실패.
- autoscaling max 적절 설정(과다 확장 비용).

---
## 5. Artifact Registry 모듈 (`modules/artifact_registry/main.tf`)
### google_artifact_registry_repository "this"
- `format = DOCKER`: 컨테이너 이미지 저장소.
- 지역 단위(멀티리전 아님). 레이턴시/DR 고려.
- 취약점 스캔/정책은 Console 또는 추가 Terraform 리소스로 확장 가능.

주의:
- 이미지 누적 비용: 정리 정책 또는 수명 규칙 적용 권장.
- 고유 repository_id 조직 컨벤션(서비스명 등).

---
## 6. Backend 설정 (`terraform/backend.tf`)
### terraform { backend "gcs" }
- 실제 state 저장소 버킷/경로 설정.
- 현재 placeholder: `bucket = "REPLACE_ME_BUCKET"` → init 시 -backend-config 사용 권장.
- 실무: state 버킷에 버전관리, 암호화, 접근 제어 최소화.

---
## 7. 서비스 계정 & IAM 바인딩
### google_service_account "terraform"
- Terraform 작업 전용.
- 추가 권한 필요 시 roles 추가 단, 최소 권한 원칙 유지.

### google_project_iam_binding
- 한 Role에 여러 멤버 배치. 여기서는 단일 SA.
- 다른 IaC나 수동 변경과 충돌 시 drift 발생 가능.
- 대안: `google_project_iam_member` (멤버 단위 세분화) 또는 커스텀 Role.

---
## 8. 일반 주의사항 & 권장 패턴
- Drift 방지: 콘솔 수동 변경 최소화.
- 네트워크 CIDR: 향후 확장 고려해 넉넉히 할당, 겹침 방지.
- Workload Identity: 서비스 계정 키 제거 방향.
- 모듈 버전 잠금(별도 Registry 사용 시) 고려.
- Observability: 기본 Managed Prometheus 외에 Alert Policy 추가 계획.
- 비용 최적화: Node Pool Spot/온디맨드 혼합, 리소스 Requests/Limits 모니터링.
- 보안: Artifact Registry 취약점 스캔, 이미지 서명(Binary Authorization) 추후 도입 가능.

---
## 9. 다음 확장 제안
- GitOps(Argo CD) 모듈 추가
- Argo Rollouts Canary/Blue-Green 패턴
- Secret Manager CSI Driver & Gatekeeper 정책 모듈
- Alert Policy (Monitoring) Terraform 리소스 추가
- Workload Identity Federation (CI/CD) 셋업 모듈

필요한 확장을 선택하면 해당 모듈/리소스 코드를 추가해 드릴 수 있습니다.
