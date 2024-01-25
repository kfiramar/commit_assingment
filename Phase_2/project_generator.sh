#!/bin/bash

# Set up project directory
project_dir="aws_infrastructure"
mkdir -p $project_dir

# VPC and Subnet Configuration
vpc_file="$project_dir/vpc.tf"
cat <<EOF > $vpc_file
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true

  tags = {
    Name = "MainVPC"
  }
}

resource "aws_subnet" "subnet1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.subnet1_cidr
  availability_zone       = var.availability_zone1
  map_public_ip_on_launch = true

  tags = {
    Name = "Subnet1"
  }
}

resource "aws_subnet" "subnet2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.subnet2_cidr
  availability_zone       = var.availability_zone2
  map_public_ip_on_launch = false

  tags = {
    Name = "Subnet2"
  }
}
EOF

# ECS Cluster, Task Definition, and Service Configuration
ecs_file="$project_dir/ecs.tf"
cat <<EOF > $ecs_file
# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "main-cluster"
}

# ECS Task Definition
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

resource "aws_security_group" "ecs_sg" {
  name        = "ecs_sg"
  description = "Allow inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ALB Configuration
resource "aws_lb" "ecs_alb" {
  name               = "ecs-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.subnet1.id, aws_subnet.subnet2.id]
  enable_deletion_protection = false
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.ecs_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs_tg.arn
  }
}

resource "aws_lb_target_group" "ecs_tg" {
  name     = "ecs-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  target_type = "ip"

  health_check {
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 3
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200-299"
    interval            = 30
  }
}

resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  description = "Security Group for ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_ecs_service" "nginx_service" {
  name            = "nginx-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.nginx.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  load_balancer {
    target_group_arn = aws_lb_target_group.ecs_tg.arn
    container_name   = "nginx"
    container_port   = 80
  }

  network_configuration {
    subnets          = [aws_subnet.subnet1.id, aws_subnet.subnet2.id]
    security_groups  = [aws_security_group.ecs_sg.id]
  }

  depends_on = [aws_lb_listener.front_end]
}
EOF

# RDS MySQL Instance Configuration
rds_file="$project_dir/rds.tf"
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
    Name = "My DB Subnet Group"
  }
}

resource "aws_security_group" "rds_sg" {
  name        = "rds_sg"
  description = "Allow inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
EOF

# Network Configuration
network_file="$project_dir/network.tf"
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

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.subnet2.id
  route_table_id = aws_route_table.private_rt.id
}
EOF

# Variables Definition
variables_file="$project_dir/variables.tf"
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
EOF

# Outputs Configuration
outputs_file="$project_dir/outputs.tf"
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
EOF

# NAT Gateway Configuration
nat_file="$project_dir/nat.tf"
cat <<EOF > $nat_file
resource "aws_eip" "nat_eip" {
  vpc = true
}

resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.subnet1.id
  depends_on    = [aws_internet_gateway.main]
}
EOF

# Initialize and Plan Terraform
cd $project_dir
terraform init
terraform plan
terraform apply
