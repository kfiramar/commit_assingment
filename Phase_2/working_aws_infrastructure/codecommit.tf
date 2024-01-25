resource "aws_codecommit_repository" "this" {
  repository_name = var.codecommit_repo_name
  description     = "Terraform managed repository for AWS infrastructure"
}
