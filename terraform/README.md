# GCP Terraform 플랫폼 스캐폴드 (GKE Private Standard)

## 구성 개요
- VPC + Subnet (GKE용 Secondary ranges 포함)
- Cloud Router + Cloud NAT (프라이빗 워크로드 아웃바운드 인터넷)
- GKE Standard Private Cluster (IP Alias, Workload Identity, Managed Prometheus 활성화)
- Artifact Registry (컨테이너 이미지 저장소)
- State 저장용 GCS 버킷 (예시 리소스, 실제 백엔드는 `backend.tf`에서 사용)
- Terraform 실행용 Service Account 및 기본 IAM 바인딩
- 필수 API 자동 활성화 (compute, container, monitoring 등)

## 디렉터리 구조 (요약)
```
terraform/
  main.tf                # 루트 구성: 네트워크, NAT, GKE, Artifact Registry, SA 등
  variables.tf           # 모든 변수 정의
  outputs.tf             # 핵심 출력 값
  backend.tf             # GCS backend 설정 (버킷 생성 후 교체 필요)
  terraform.tfvars.example
  modules/
    network/             # VPC + Subnet + Secondary ranges
    nat/                 # Cloud Router + NAT
    gke/                 # GKE Private Cluster + Node Pool
    artifact_registry/   # Artifact Registry 리포지토리
```

## 변수 예시 파일 `terraform.tfvars`
```hcl
project_id         = "your-project-id"
state_bucket_name  = "your-unique-tf-state-bucket"
credentials_file   = "./service-account-key.json" # 또는 ADC 사용 시 생략
cluster_name       = "gke-primary"
region             = "asia-northeast3"
zone               = "asia-northeast3-a"
vpc_name           = "primary-vpc"
primary_subnet_name = "primary-subnet"
primary_subnet_cidr = "10.10.0.0/24"
pods_secondary_cidr     = "10.20.0.0/16"
services_secondary_cidr = "10.30.0.0/20"
pods_secondary_range_name     = "pods"
services_secondary_range_name = "services"
artifact_registry_repo = "apps"
# enable_apis = ["compute.googleapis.com", "container.googleapis.com", ...] # 기본값 이미 포함
```

## 사전 준비
1. 프로젝트 존재 여부 확인: `gcloud projects describe your-project-id`
2. 인증
   - `gcloud auth login`
   - `gcloud auth application-default login` (ADC 사용)
   - 또는 서비스 계정 키 JSON 발급 후 `credentials_file` 지정
3. Terraform 설치 후 버전 확인: `terraform version`
4. State 버킷 사전 생성 (예: `gsutil mb -l asia-northeast3 gs://your-unique-tf-state-bucket/`)

## 초기화 & 실행
```bash
terraform init \
  -backend-config="bucket=your-unique-tf-state-bucket" \
  -backend-config="prefix=tfstate/root"

terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

## 클러스터 접근 및 확인
```bash
# kubeconfig 설정
gcloud container clusters get-credentials gke-primary --region asia-northeast3 --project your-project-id

kubectl get nodes -o wide
kubectl get ns
kubectl get pods -A
```

## 주요 출력 값 (terraform apply 후)
- `gke_cluster_name` : 클러스터 이름
- `artifact_registry_repo` : 레포지토리 ID
- `vpc_self_link` / `subnet_self_links` : 네트워크 참조

## 구성 설명
| 모듈 | 목적 | 주요 포인트 |
|------|------|-------------|
| network | VPC/Subnet/Secondary ranges | GKE IP Alias 위해 pods/services CIDR 분리 |
| nat | Private 노드 아웃바운드 | Cloud Router + NAT (ERRORS_ONLY 로그) |
| gke | Private Standard Cluster | Workload Identity + Managed Prometheus + Release Channel |
| artifact_registry | 컨테이너 저장소 | 취약점 스캔(콘솔 설정) 권장 |

## 검증 체크리스트
- Subnet에 secondary ranges 정상 생성 (`gcloud compute networks subnets describe ...`)
- GKE 클러스터 생성 후 노드 IP가 기본 CIDR, Pod/Service IP가 Secondary CIDR 사용
- NAT 존재 여부: `gcloud compute routers nats list --router=router-<region> --region=<region>`
- Artifact Registry 리포지토리: `gcloud artifacts repositories list --location=<region>`

## 다음 단계 제안 (2차 마일스톤)
- GitOps(Argo CD) 설치: bootstrap manifest 또는 헬름
- Progressive Delivery(Argo Rollouts) Canary
- Secret Manager CSI Driver → 시크릿 키리스 주입
- Gatekeeper 정책(네임스페이스 라벨 필수/privileged 금지)
- 기본 알람 정책(CPU, 5xx 비율, p95 latency) Terraform으로 추가
- CI 파이프라인(Cloud Build 또는 GitHub Actions OIDC) 이미지 빌드/태깅
- Binary Authorization / 취약점 스캔 리포트 문서화

## 장애/운영 시나리오 기록 가이드
- 이미지 Pull 실패: NAT/Firewall 확인
- 특정 Pod OOM: Resource Requests/Limits 재조정 + HPA 반응 로그
- Canary 실패 자동 롤백: Argo Rollouts 이벤트 캡처
- 정책 위반 배포 차단: Gatekeeper Constraint 결과 캡처

## 비용 최적화 힌트
- Node Pool 혼합(온디맨드 + Spot) / autoscaling 범위 튜닝
- 요청/리밋 과대 설정 탐지 (Prometheus metrics / kube-state-metrics)
- Artifact Registry 청소 정책(Tag/Retention)

---
이후 GitOps & Observability 확장을 진행하려면 요청 주세요. 아키텍처 다이어그램/추가 문서(`docs/`)도 확장 가능합니다.
