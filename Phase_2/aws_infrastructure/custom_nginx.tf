resource "aws_ecs_task_definition" "custom_nginx" {
  family                   = "custom_nginx"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn

  container_definitions = jsonencode([{
    name  = "custom_nginx",
    image = "your_custom_nginx_image", # Use your custom Docker image URL here
    portMappings = [{
      containerPort = 80,
      hostPort      = 80
    }]
  }])
}

resource "aws_ecs_service" "custom_nginx_service" {
  name            = "custom-nginx-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.custom_nginx.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  load_balancer {
    target_group_arn = aws_lb_target_group.ecs_tg.arn
    container_name   = "custom_nginx"
    container_port   = 80
  }

  network_configuration {
    subnets          = [aws_subnet.subnet1.id, aws_subnet.subnet2.id]
    security_groups  = [aws_security_group.ecs_sg.id]
  }

  depends_on = [aws_lb_listener.front_end]
}
