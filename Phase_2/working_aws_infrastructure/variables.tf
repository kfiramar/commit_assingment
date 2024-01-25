variable "vpc_cidr" {
  description = "CIDR for VPC"
  default     = "10.0.0.0/16"
}

variable "subnet1_cidr" {
  description = "CIDR for subnet 1"
  default     = "10.0.1.0/24"
}

variable "subnet2_cidr" {
  description = "CIDR for subnet 2"
  default     = "10.0.2.0/24"
}

variable "availability_zone1" {
  description = "Availability Zone for subnet 1"
  default     = "eu-west-1a"
}

variable "availability_zone2" {
  description = "Availability Zone for subnet 2"
  default     = "eu-west-1b"
}

variable "codecommit_repo_name" {
  description = "Name for the CodeCommit repository"
  default     = "my-terraform-repo"
}
