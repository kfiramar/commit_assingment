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
