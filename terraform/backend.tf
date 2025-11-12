terraform {
  # 원격 상태 저장소 백엔드 설정(GCS)
  # 실제 버킷 값은 terraform init 시 -backend-config 옵션으로 주입하는 것을 권장
  
  # 로컬 개발용: GCS 백엔드를 주석 처리하고 로컬 백엔드 사용
  # backend "gcs" {
  #   bucket = "REPLACE_ME_BUCKET" # 플레이스홀더; 실제 버킷 이름을 하드코딩하지 마세요
  #   prefix = "tfstate/root"      # 상태 파일이 저장될 버킷 내 경로/프리픽스
  # }
}
