variable "region" {
  default = "europe-west1"
}

variable "region_zone" {
  default = "europe-west1-b"
}

variable "project_name" {
  default = "otus-k8s"
}

variable "credentials_file_path" {
  description = "Path to the JSON file used to describe your account credentials"
  default     = "credentials.json"
}

variable "public_key_path" {
  description = "Path to file containing public key"
  default     = "~/.ssh/google_compute_engine.pub"
}

variable "private_key_path" {
  description = "Path to file containing private key"
  default     = "~/.ssh/google_compute_engine"
}

