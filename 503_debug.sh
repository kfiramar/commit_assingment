#!/bin/bash

# Set required variables
cluster_name="main-cluster"
service_name="nginx-service"
target_group_arn="arn:aws:elasticloadbalancing:eu-west-1:533267130709:targetgroup/ecs-tg/7d364e8d84bd2388"
load_balancer_dns="ecs-alb-638370155.eu-west-1.elb.amazonaws.com"
region="eu-west-1"

# Check ECS Service and Load Balancer Association
echo "Checking ECS Service and Load Balancer Association..."
aws ecs describe-services --cluster $cluster_name --services $service_name --region $region

# Verify Target Group Health Checks and Registered Targets
echo "Verifying Target Group Health Checks and Registered Targets..."
aws elbv2 describe-target-health --target-group-arn $target_group_arn --region $region

# Retrieve and Display ECS Task Logs
echo "Retrieving and Displaying ECS Task Logs..."
task_id=$(aws ecs list-tasks --cluster $cluster_name --service-name $service_name --region $region --query "taskArns[0]" --output text)
log_stream_name=$(aws ecs describe-tasks --cluster $cluster_name --tasks $task_id --region $region --query "tasks[0].containers[0].logStreamName" --output text)

if [ "$log_stream_name" != "None" ]; then
    aws logs get-log-events --log-group-name "/ecs/$service_name" --log-stream-name $log_stream_name --region $region --limit 100
else
    echo "Log stream not found for task $task_id"
fi

# Test Connectivity to the ALB DNS Name
echo "Testing Connectivity to the ALB DNS Name..."
curl -I $load_balancer_dns

echo "Script Execution Completed!"