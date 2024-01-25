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
