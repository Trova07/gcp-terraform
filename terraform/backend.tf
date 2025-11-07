terraform {
  backend "gcs" {
    bucket = "REPLACE_ME_BUCKET" # 또는 -backend-config 옵션 사용 권장
    prefix = "tfstate/root"
  }
}
