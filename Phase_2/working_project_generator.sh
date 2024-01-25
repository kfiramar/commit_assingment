#!/bin/bash

# Set up project directory
project_dir="aws_infrastructure"
mkdir -p $project_dir

# Define file names
vpc_file="$project_dir/vpc.tf"
ecs_file="$project_dir/ecs.tf"
rds_file="$project_dir/rds.tf"
network_file="$project_dir/network.tf"
codecommit_file="$project_dir/codecommit.tf"
codepipeline_file="$project_dir/codepipeline.tf"
variables_file="$project_dir/variables.tf"
outputs_file="$project_dir/outputs.tf"



# VPC and Subnets Configuration
cat <<EOF > $vpc_file
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  enable_dns_hostnames = true
  tags = {
    Name = "MainVPC"
  }
}

resource "aws_subnet" "subnet1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.subnet1_cidr
  availability_zone = var.availability_zone1
  map_public_ip_on_launch = true
  tags = {
    Name = "Subnet1"
  }
}

resource "aws_subnet" "subnet2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.subnet2_cidr
  availability_zone = var.availability_zone2
  map_public_ip_on_launch = true
  tags = {
    Name = "Subnet2"
  }
}
EOF

# ECS Cluster and Task Definition
cat <<EOF > $ecs_file
resource "aws_ecs_cluster" "main" {
  name = "main-cluster"
}

resource "aws_ecs_task_definition" "nginx" {
  family                   = "nginx"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn

  container_definitions = jsonencode([{
    name  = "nginx",
    image = "nginx:latest",
    portMappings = [{
      containerPort = 80,
      hostPort      = 80
    }]
  }])
}

resource "aws_iam_role" "ecs_execution_role" {
  name = "ecs_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}
EOF

# RDS Instance Configuration
cat <<EOF > $rds_file
resource "aws_db_instance" "main" {
  allocated_storage    = 20
  storage_type         = "gp3"
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = "db.t3.micro"
  db_name              = "mydb"
  username             = "user"
  password             = "Passw0rd$2023"
  parameter_group_name = "default.mysql5.7"
  db_subnet_group_name = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  skip_final_snapshot  = true
}

resource "aws_db_subnet_group" "main" {
  name       = "my-db-subnet-group"
  subnet_ids = [aws_subnet.subnet1.id, aws_subnet.subnet2.id]
  tags = {
    Name = "My DB subnet group"
  }
}

resource "aws_security_group" "rds_sg" {
  name        = "rds_sg"
  description = "Allow all inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
EOF

# Network Configuration
cat <<EOF > $network_file
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.main.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.subnet2.id
  route_table_id = aws_route_table.main.id
}
EOF

# CodeCommit Repository Configuration
cat <<EOF > $codecommit_file
resource "aws_codecommit_repository" "this" {
  repository_name = var.codecommit_repo_name
  description     = "Terraform managed repository for AWS infrastructure"
}
EOF

# CodePipeline Configuration (Placeholder)
cat <<EOF > $codepipeline_file
# Add your CodePipeline configuration here
EOF

# Variables Definition
cat <<EOF > $variables_file
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
EOF

# Outputs Configuration
cat <<EOF > $outputs_file
output "vpc_id" {
  value = aws_vpc.main.id
}

output "subnet_ids" {
  value = [aws_subnet.subnet1.id, aws_subnet.subnet2.id]
}

output "ecs_cluster_arn" {
  value = aws_ecs_cluster.main.arn
}

output "rds_instance_address" {
  value = aws_db_instance.main.address
}

output "codecommit_repo_clone_url_http" {
  value = aws_codecommit_repository.this.clone_url_http
}
EOF


# Initialize and Plan Terraform
cd $project_dir
terraform init
terraform plan
