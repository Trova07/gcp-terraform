# GKE Secure DevOps 프로젝트 계획

## 1. 프로젝트 개요
- **목표**: Private GKE 기반의 운영·보안 강화형 클러스터를 구축하고, Cloud Build → Artifact Registry → Argo CD(또는 Cloud Deploy)를 연동한 CI/CD 파이프라인을 구성해 DevOps 전 과정을 경험한다.
- **성과물**: Terraform 인프라 코드, 보안 설정(Binary Authorization, Gatekeeper 등), 애플리케이션 샘플, 빌드/배포 파이프라인 설정, 운영 문서.
- **기간 가정**: 4~6주 (주당 6~8시간 투자 기준) — 필요 시 조정.

## 2. 상위 아키텍처
- **인프라 레이어**: VPC, Private GKE, Cloud NAT, Artifact Registry, Secret Manager, Cloud Logging/Monitoring.
- **보안 레이어**: Cloud Armor + HTTPS LB, Binary Authorization, Gatekeeper 정책, IAM 조건부 권한, 로그 싱크/알림.
- **CI/CD 레이어**: Cloud Build(이미지 빌드) → Artifact Registry → Argo CD(or Cloud Deploy) 자동배포, GitOps 리포 구조.
- **운영 관점**: 관찰성(Alert Policy), 비용/권한 관리, 재해복구 전략(백업, Multi-Zone).

## 3. 단계별 계획

### Phase 1 — 준비 및 기본 인프라
- 현재 Terraform 스캐폴드 정리: 변수/모듈 구조 점검, 환경 분리 전략 정의(dev/prod).
- 백엔드 상태 구성: GCS backend 적용, Terraform 워크플로우 확정.
- IAM 정책 설계: Terraform SA/CI SA/애플리케이션 SA 권한 분리.
- 산출물: 수정된 Terraform 구조, 환경별 변수 세트, 문서 업데이트.

### Phase 2 — GKE 운영·보안 강화
- Cloud Armor + HTTPS External LB 구성(Managed Certificate, SSL Policy).
- Binary Authorization 정책 정의 및 Sigstore/Built-in Attestor 구성.
- Gatekeeper(OPA) 정책 예시 적용(네임스페이스 격리, 레이블 필수, RunAsNonRoot 등).
- Secret Manager + Workload Identity로 애플리케이션 비밀 연동.
- Cloud Logging/Monitoring: 로그 싱크(BigQuery or Log Bucket), Alert Policy(노드 부족, Pod CrashLoop 등) 추가.
- 산출물: 보안/운영 Terraform 모듈, 정책 정의서.

### Phase 3 — CI 파이프라인 구성
- Cloud Build 기반 이미지 빌드/테스트 파이프라인 작성(cloudbuild.yaml).
- Build SA 권한 최소화 설정(Artifact Registry, KMS, Secret Manager 등).
- 테스트 자동화(단위 테스트, SAST/컨테이너 스캔) 단계 포함.
- Terraform으로 Cloud Build Trigger 정의(브랜치/태그 전략).
- 산출물: Cloud Build 설정, 샘플 애플리케이션 리포, 보안 스캔 보고 흐름.

### Phase 4 — CD 및 GitOps 흐름
- Argo CD 설치(Helm/Terraform) 또는 Cloud Deploy 설정.
- GitOps 레포 구조 설계: base/overlays(dev/prod), 네임스페이스 분리.
- Progressive delivery(Argo Rollouts / Cloud Deploy phases) 테스트.
- 배포 승인 정책(Binary Authorization, Gatekeeper)과 연계 시나리오 검증.
- 산출물: GitOps 매니페스트, Argo CD(또는 Cloud Deploy) 설정, 운영 Runbook.

### Phase 5 — 운영 자동화 및 마무리
- 관찰성 대시보드 생성(Managed Prometheus, Cloud Monitoring Dashboard).
- 비용/로그 관리 정책(로그 보존, 배포 빈도) 정리.
- DR/백업 전략(Artifact Registry, GKE 백업&DR, Terraform state 백업) 문서화.
- 최종 리드미/아키텍처 다이어그램/데모 스크립트 작성.
- 산출물: 운영 문서, 발표 자료, 향후 개선 로드맵.

## 4. 역할/책임
- **Infra & Security**: Terraform 모듈 개발, IAM/보안 정책 구현.
- **CI/CD**: Cloud Build/Argo CD 설정, 테스트 자동화, GitOps 프로세스 정의.
- **Operations**: 모니터링·알림 설정, Runbook/DR 전략 수립, 비용 최적화.

## 5. 필요 기술 스택
- Terraform, GCP(GKE, Cloud Armor, Artifact Registry, Secret Manager, Cloud Monitoring/Logging)
- Kubernetes(Helm, Kustomize, Gatekeeper), Argo CD/Argo Rollouts 또는 Cloud Deploy
- Cloud Build, Container Scanning(Artifact Analysis or Trivy), GitHub/GitLab

## 6. 리스크 및 대비
- **비용 초과**: 사전 예산 책정, 작은 노드 사이즈/auto-scaling 제한으로 관리.
- **권한 관리 복잡도**: IAM 설계 문서화, Terraform state drift 주의.
- **보안 정책 충돌**: Gatekeeper/Binary Authorization 테스트 환경 분리, 예외 처리 절차 확립.
- **배포 실패**: GitOps 롤백 전략, Canary/Blue-Green으로 점진 배포.

## 7. 성공 기준
- Terraform으로 인프라 전체 재현 가능.
- Cloud Build → Artifact Registry → GitOps 배포까지 자동 실행.
- 보안 정책(BA, Gatekeeper)이 잘 적용되어 위반 시 차단/경고.
- 운영 지표/알림이 활성화되어 클러스터 상태를 빠르게 파악 가능.
- 최종 문서와 데모가 포트폴리오/발표에 활용 가능.

## 8. 후속 확장 아이디어
- Policy-as-Code(OPA Rego, Terraform Sentinel) 추가.
- Multi-project/Shared VPC 구조로 확장, 조직 정책(Organization Policy) 적용.
- Cloud Deploy로 멀티 리전 배포, Anthos Config Management 탐색.
- GitHub Actions OIDC + Workload Identity Federation로 CI 보안 강화.

