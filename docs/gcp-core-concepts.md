# GCP 핵심 개념 가이드 (AWS 대비)

이 문서는 AWS 경험자를 대상으로 GCP에서 꼭 알아야 할 개념을 빠르게 익히도록 제작되었습니다. 섹션마다 AWS와의 비교, Terraform 리소스명, 실무 함정(주의점)을 함께 정리했습니다.

---

## 1. 리소스 계층 구조 (Resource Hierarchy)
- Organization → Folder → Project → (Billing Account는 별도 연결)
- 모든 리소스는 반드시 하나의 Project에 소속됩니다.
- AWS 대응: Organizations Root/OU, 단일 Account에 해당하는 것이 Project.
- Terraform: provider `google { project = ... }`에 지정. 프로젝트 변경은 대부분 재생성.
- 주의: 프로젝트 삭제는 유예 후 영구 삭제. state 고아 리소스 주의.

## 2. IAM & 액세스
- Role 유형: Primitive(Owner/Editor/Viewer), Predefined(세분화), Custom.
- Service Account: 앱/자동화용 ID. 장기 키(JSON) 대신 가급적 키리스 권장.
- Workload Identity Federation: GitHub Actions 등 외부 OIDC에서 키 없이 임시 권한.
- Workload Identity(GKE): Pod → Google SA 매핑(IRSA 유사).
- Terraform 주요 리소스: `google_service_account`, `google_project_iam_binding`, `google_project_iam_member`, `google_project_iam_custom_role`.
- 함정: Binding(다수 멤버) vs Member(한 멤버) 차이. 키 파일 저장 금지.

## 3. 네트워킹
- VPC(글로벌), Subnet(리전), Firewall(Stateful).
- Cloud Router + Cloud NAT: 프라이빗 서브넷의 아웃바운드.
- Private Service Connect / VPC Peering / Shared VPC: 프로젝트 간 통신.
- Terraform: `google_compute_network`, `google_compute_subnetwork`, `google_compute_firewall`, `google_compute_router`, `google_compute_router_nat`.
- 함정: Compute API 미활성 → Apply 실패. NAT IP/비용 고려.

## 4. 컨테이너 & 워크로드 (GKE)
- Standard vs Autopilot(노드 관리 최소화, 제약/비용 구조 상이).
- Node Pool, Private Cluster, IP Alias(권장), Workload Identity.
- Terraform: `google_container_cluster`, `google_container_node_pool`.
- 함정: `container.googleapis.com` 활성화, Private + NAT 구성 누락, Autopilot 제약.

## 5. Compute
- Compute Engine(EC2), Template/MIG(ASG 유사), Preemptible(Spot 유사).
- Terraform: `google_compute_instance`, `google_compute_instance_template`, `google_compute_region_instance_group_manager`.
- 함정: Preemptible 안정성, SA 권한/스코프 분리.

## 6. 스토리지
- Cloud Storage(GCS): 객체 스토리지, 버킷 이름 전역 고유.
- UBLA(권장): 객체 ACL 제거, IAM만 사용.
- Terraform: `google_storage_bucket`, `google_storage_bucket_iam_member`.
- 함정: 버킷 이름 재사용/락, 삭제 주의.

## 7. 데이터 & 메시징
- Cloud SQL(RDS), Spanner(글로벌 RDB), BigQuery(서버리스 분석), Pub/Sub(SNS+SQS 유사).
- Terraform: `google_sql_database_instance`, `google_pubsub_*`, `google_bigquery_*`.
- 함정: Cloud SQL Private IP 설정/네트워킹, BigQuery 스캔 비용.

## 8. 서버리스
- Cloud Functions(이벤트 함수), Cloud Run(컨테이너 서버리스), App Engine(레거시 경향).
- Terraform: `google_cloudfunctions_function`, `google_cloud_run_service`.
- 함정: Cloud Run 인증/퍼블릭 설정, 최소 인스턴스 비용.

## 9. 빌드/배포 & 아티팩트
- Cloud Build(CI/CD), Artifact Registry(이미지/패키지), Deployment Manager(네이티브 IaC).
- Terraform: `google_artifact_registry_repository`, `google_cloudbuild_trigger`.
- 함정: Cloud Build SA 권한 누락.

## 10. 관찰성
- Cloud Logging/Monitoring(Stackdriver), Error Reporting/Trace/Profiler.
- Terraform(선택): `google_logging_project_sink`, `google_monitoring_alert_policy`.
- 함정: Sink Writer 권한.

## 11. 보안
- Cloud KMS, Secret Manager, Organization Policy, VPC Service Controls.
- Terraform: `google_kms_*`, `google_secret_manager_*`, `google_org_policy_policy`.
- 함정: KMS rotation/삭제보호, Secret 버전 관리.

## 12. 비용 & 할당량(Quota)
- API별 기본 제한 존재, 증설 신청 필요할 수 있음.
- 라벨로 비용 태깅(AWS Tags 유사).
- 함정: Region별 한도 → 대량 배포 전 확인.

## 13. 필수 API 예시
- compute.googleapis.com
- iam.googleapis.com
- storage.googleapis.com
- container.googleapis.com (GKE)
- cloudresourcemanager.googleapis.com
- serviceusage.googleapis.com
- logging.googleapis.com / monitoring.googleapis.com
- artifactregistry.googleapis.com
- secretmanager.googleapis.com

## 14. Terraform 네이밍 맵(요약)
- VPC: `google_compute_network` / AWS `aws_vpc`
- Subnet: `google_compute_subnetwork` / `aws_subnet`
- Firewall: `google_compute_firewall` / `aws_security_group`
- NAT: `google_compute_router_nat`(+router) / `aws_nat_gateway`
- GKE: `google_container_cluster` / `aws_eks_cluster`
- Node Pool: `google_container_node_pool` / `aws_eks_node_group`
- Object Storage: `google_storage_bucket` / `aws_s3_bucket`
- Service Account: `google_service_account` / (역할 측면) `aws_iam_role`
- IAM Binding: `google_project_iam_binding` / `aws_iam_role_policy_attachment`
- Pub/Sub Topic: `google_pubsub_topic` / `aws_sns_topic`
- Pub/Sub Sub: `google_pubsub_subscription` / `aws_sqs_queue`
- Cloud Run: `google_cloud_run_service` / `aws_apprunner_service`(또는 lambda+api)
- Secret: `google_secret_manager_secret` / `aws_secretsmanager_secret`
- KMS Key: `google_kms_crypto_key` / `aws_kms_key`

## 15. 설계 패턴
- 프로젝트 분리: network / app / security, Shared VPC로 연결.
- 모듈화: network, iam, gke, storage, observability 등.
- 환경별: prod / stage / dev 프로젝트 또는 Terraform Workspaces.
- SA 분리: Terraform SA / CI SA / App SA 최소 권한 원칙.

## 16. 자주 겪는 함정(핵심)
- API 활성화 누락 → 첫 apply 실패.
- GKE private cluster NAT 누락 → 이미지 Pull 실패.
- setIamPolicy 오버라이드 주의.
- Artifact Registry vs GCR 혼동.
- Cloud SQL 네트워크/접근 경로 불일치.
- BigQuery 대량 스캔 비용.
- SA 키 파일 유출 위험.

## 17. 학습 순서 제안
1) Resource Hierarchy & IAM → 2) VPC/Subnet/Firewall → 3) GKE(Standard/Autopilot) → 4) Storage & SA → 5) Observability → 6) Workload Identity → 7) 보안(KMS/Secret) → 8) Pub/Sub & Cloud SQL/BigQuery → 9) CI/CD → 10) 비용/Quota.

## 18. 심화 키워드
- Cloud Armor, IAP, BeyondCorp
- Anthos, Config Controller
- Dataflow, Vertex AI
- VPC Service Controls

---

### 다음 단계
아래 중 하나를 선택해 실습으로 이어갈 수 있습니다.
- GKE Standard 클러스터 + Private 네트워킹 + Workload Identity 예제
- Cloud NAT + Router + 방화벽 규칙 패턴
- Artifact Registry + Cloud Build 트리거 + 배포 파이프라인
- Secret Manager를 GKE에서 안전하게 사용하는 패턴

요청 주제를 알려주시면 해당 Terraform 코드와 함께 디렉터리/모듈을 추가해 드리겠습니다.