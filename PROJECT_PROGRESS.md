# 프로젝트 진행 요약 (GCP + Terraform + GKE)

최종 업데이트: 2025-11-07

이 문서는 현재 레포의 진행 상황과 재개(Resume) 방법을 빠르게 확인할 수 있도록 정리했습니다. 다음에 이어서 진행할 때 이 문서만 보면 됩니다.

---

## 지금까지 한 일
1) 초기 스캐폴드 구성
- terraform/ 디렉터리 생성
- provider/google, 변수/출력/백엔드 템플릿 추가
- .gitignore, 예시 tfvars, README 작성

2) 필수 API 자동 활성화 추가
- serviceusage/compute/storage/iam/container/logging/monitoring/artifactregistry 등 `google_project_service`로 enable

3) 네트워크 및 모듈 구성 강화
- modules/network: VPC + Subnet + Secondary IP ranges(pods/services) 지원
- modules/nat: Cloud Router + Cloud NAT (프라이빗 워크로드 아웃바운드)
- modules/gke: GKE Standard Private Cluster(IP Alias, Workload Identity, Managed Prometheus) + Node Pool
- modules/artifact_registry: 컨테이너 이미지 저장소

4) 문서화
- `docs/gcp-core-concepts.md`: GCP 핵심 개념(AWS 대비) 정리
- `terraform/README.md`: 변수/실행 방법/검증 체크리스트 정리

5) gcloud 설정/인증 안내
- gcloud 설치 방법(WSL/Windows)
- `gcloud auth login` + `gcloud auth application-default login`
- 프로젝트/리전/존 설정: `gcloud config set project ...`
- ADC Quota Project 설정: `gcloud auth application-default set-quota-project ...` (적용 완료)

---

## 현재 상태 점검(빠른 확인)
```bash
# gcloud가 인식 중인 프로젝트 확인
gcloud config list --format="value(core.project)"   # => clean-pen-471811-t0

# ADC 파일(로컬 사용자 자격증명) 쿼터 프로젝트 설정 완료
grep quotaProject ~/.config/gcloud/application_default_credentials.json || true
```

환경 태그(environment) 관련 경고는 정보성입니다. 꼭 필요하지 않다면 무시해도 Terraform/GKE 구성에 영향 없습니다. (원하면 라벨/태그 추가 가능)

---

## 다음에 이어서 할 일(Quick Start)
1) 변수 채우기
```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# 파일 열어 project_id, state_bucket_name, region/zone 등 내 값으로 수정
```

2) 백엔드 버킷(GCS) 준비 후 초기화
```bash
# (버킷이 없다면 먼저 생성)
# gsutil mb -l asia-northeast3 gs://YOUR_STATE_BUCKET/

cd terraform
terraform init \
  -backend-config="bucket=YOUR_STATE_BUCKET" \
  -backend-config="prefix=tfstate/root"
```

3) 계획/적용
```bash
terraform fmt
terraform validate
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

4) 클러스터 접근 확인
```bash
gcloud container clusters get-credentials gke-primary \
  --region asia-northeast3 \
  --project clean-pen-471811-t0

kubectl get nodes -o wide
kubectl get pods -A
```

---

## 구성 개요(요약)
- Network: VPC + Subnet + Secondary ranges(pods/services), Private Google Access
- NAT: Cloud Router + NAT (ERRORS_ONLY 로깅)
- GKE: Standard Private Cluster, IP Alias, Workload Identity, Managed Prometheus, 기본 Node Pool
- Artifact Registry: 컨테이너 이미지 저장소(repo: apps)
- State: GCS Backend 사용(버킷은 별도 생성/지정)

주요 파일
- `terraform/main.tf` — 모듈 연결과 API 활성화, SA/IAM 예시
- `terraform/variables.tf` — 모든 변수 정의(secondary ranges 포함)
- `terraform/modules/*` — network, nat, gke, artifact_registry 모듈
- `terraform/outputs.tf` — 클러스터/레포 등 출력

---

## 트러블슈팅 메모
- API not enabled 에러: 첫 apply 전에 `google_project_service`가 해결. CLI 사용 중에도 자동 enable 요청 가능.
- environment tag 경고: 정보성. 필요 시 라벨/태그 추가.
- 라벨 추가(일부 환경에선 alpha 필요):
```bash
# 필요 시 alpha 설치: sudo apt-get install -y google-cloud-cli-alpha
gcloud alpha projects update clean-pen-471811-t0 \
  --update-labels environment=development,purpose=education
```
- 태그(Resource Manager Tags) 바인딩은 정책 목적일 때만:
```bash
# alpha 명령으로 key/value 생성 후 binding (상세는 문서 참고)
```
- 인증 체인: 로컬은 ADC 권장. CI는 WIF(Workload Identity Federation)+임퍼서네이션 권장.

---

## 다음 마일스톤 제안(선택)
- GitOps(Argo CD) 부트스트랩 + App of Apps 구조
- 샘플 마이크로서비스 2~3개 + Kustomize overlays(dev/prod)
- CI 파이프라인(Cloud Build 또는 GitHub Actions OIDC) — 빌드/푸시
- Argo Rollouts로 Canary 배포
- Secret Manager CSI Driver, Gatekeeper 정책, 기본 Alert Policies

필요한 항목을 선택해 달라고 요청하면 해당 모듈/매니페스트를 레포에 바로 추가해 드립니다.
