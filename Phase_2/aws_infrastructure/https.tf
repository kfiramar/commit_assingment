resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.ecs_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"

  # Use your self-signed certificate ARN
  certificate_arn   = "arn:aws:acm:eu-west-1:533267130709:certificate/74be48f4-b65a-43ff-a50f-dda4e1f93a7a" 

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs_tg.arn
  }
}