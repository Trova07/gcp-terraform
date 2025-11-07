# GCP Terraform 기본 스캐폴드

## 구성 개요
- VPC + Subnet (모듈화)
- State 저장용 GCS 버킷 (예시 리소스, 실제 백엔드는 `backend.tf`에서 사용)
- Terraform 실행용 Service Account 및 기본 IAM 바인딩

## 사전 준비
1. GCP 프로젝트 존재: `gcloud projects list`
2. 서비스 계정 생성용 권한 (Project IAM Admin 또는 적절한 제한 권한)
3. Terraform 설치: https://developer.hashicorp.com/terraform/downloads
4. 인증 방법 중 하나 선택:
   - (권장) Application Default Credentials: `gcloud auth application-default login`
   - 서비스 계정 JSON 키 파일 사용: 변수 `credentials_file` 지정

## 변수 예시 파일 `terraform.tfvars`
```hcl
project_id         = "your-project-id"
state_bucket_name  = "your-unique-tf-state-bucket"
credentials_file   = "./service-account-key.json" # 또는 ADC 사용 시 생략
```

버킷은 먼저 콘솔이나 gcloud로 수동 생성 후 backend 블록 수정하거나, 임시로 resource를 apply 한 뒤 backend 재구성 필요.

## 초기화 & 실행
```bash
# 백엔드 버킷 아직 없으면 먼저 수동 생성 (또는 resource로 한번 apply 후 backend 수정)
# gcloud auth login 및 ADC 구성

terraform init \
  -backend-config="bucket=your-unique-tf-state-bucket" \
  -backend-config="prefix=tfstate/root"

terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

## 네트워크 모듈 확장
추가 Subnet 필요 시 `subnet_configs`에 객체 추가:
```hcl
subnet_configs = [
  { name = "primary-subnet", ip_cidr_range = "10.10.0.0/24", region = var.region },
  { name = "secondary-subnet", ip_cidr_range = "10.10.1.0/24", region = var.region }
]
```

## 다음 단계 제안
- Backend 버킷 encryption / 버킷 권한 최소화
- 모듈 분리 (iam, storage, compute, gke 등)
- 환경별 워크스페이스 또는 디렉터리 (dev/stage/prod)
- CI/CD (GitHub Actions, Cloud Build)에서 terraform fmt/validate/plan/apply 파이프라인
- Terraform Cloud 또는 정책 가드레일 (Sentinel, OPA) 도입

---
문제나 확장 필요 시 이슈로 남겨주세요.
