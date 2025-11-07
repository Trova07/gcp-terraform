variable "project_id" {
  description = "Existing GCP Project ID"
  type        = string
}

variable "region" {
  description = "Default region"
  type        = string
  default     = "asia-northeast3"
}

variable "zone" {
  description = "Default zone"
  type        = string
  default     = "asia-northeast3-a"
}

variable "credentials_file" {
  description = "Path to service account JSON key (optional if using ADC)"
  type        = string
  default     = ""
}

variable "state_bucket_name" {
  description = "GCS bucket name for Terraform state (must be globally unique)"
  type        = string
}

variable "tf_sa_id" {
  description = "Service Account ID (without domain) to create for Terraform runs"
  type        = string
  default     = "tf-automation"
}

variable "vpc_name" {
  description = "Name of the VPC"
  type        = string
  default     = "primary-vpc"
}

variable "primary_subnet_cidr" {
  description = "CIDR for primary subnet"
  type        = string
  default     = "10.10.0.0/24"
}

variable "enable_apis" {
  description = "List of Google APIs to enable in the project"
  type        = list(string)
  default = [
    "compute.googleapis.com",
    "storage.googleapis.com",
    "iam.googleapis.com",
    "container.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "serviceusage.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "artifactregistry.googleapis.com"
  ]
}

variable "primary_subnet_name" {
  description = "Name of the primary subnet to create/use"
  type        = string
  default     = "primary-subnet"
}

variable "pods_secondary_cidr" {
  description = "Secondary range CIDR for GKE Pods"
  type        = string
  default     = "10.20.0.0/16"
}

variable "services_secondary_cidr" {
  description = "Secondary range CIDR for GKE Services"
  type        = string
  default     = "10.30.0.0/20"
}

variable "pods_secondary_range_name" {
  description = "Secondary range name for Pods"
  type        = string
  default     = "pods"
}

variable "services_secondary_range_name" {
  description = "Secondary range name for Services"
  type        = string
  default     = "services"
}

variable "cluster_name" {
  description = "GKE cluster name"
  type        = string
  default     = "gke-primary"
}

variable "artifact_registry_repo" {
  description = "Artifact Registry repository id"
  type        = string
  default     = "apps"
}
