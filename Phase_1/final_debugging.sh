#!/bin/bash

# Script to debug AWS ECS, Load Balancer, Security Group, and RDS instance.

echo "---- ECS Cluster Info ----"
aws ecs describe-clusters --clusters KfirEcsCluster

echo "---- ECS Service Info ----"
aws ecs describe-services --cluster KfirEcsCluster --services kfir-nginx-service

echo "---- ECS Task Definitions ----"
aws ecs describe-task-definition --task-definition KfirEcsCluster

echo "---- ECS Task Info ----"
TASK_ARN=$(aws ecs list-tasks --cluster KfirEcsCluster --service-name kfir-nginx-service --query "taskArns[0]" --output text)
aws ecs describe-tasks --cluster KfirEcsCluster --tasks $TASK_ARN

echo "---- ECS Task Logs ----"
# Assuming you have set up AWS CloudWatch logs
LOG_GROUP_NAME="/aws/ecs/KfirEcsCluster"
aws logs describe-log-streams --log-group-name $LOG_GROUP_NAME
# Replace with the appropriate log stream name
LOG_STREAM_NAME="your-log-stream-name"
aws logs get-log-events --log-group-name $LOG_GROUP_NAME --log-stream-name $LOG_STREAM_NAME

echo "---- Load Balancer Info ----"
aws elbv2 describe-load-balancers --names kfir-lb

echo "---- Target Group Info ----"
aws elbv2 describe-target-groups --names kfir-tg

echo "---- Load Balancer Listener Info ----"
LB_ARN=$(aws elbv2 describe-load-balancers --names kfir-lb --query "LoadBalancers[0].LoadBalancerArn" --output text)
aws elbv2 describe-listeners --load-balancer-arn $LB_ARN

echo "---- Target Group Health Info ----"
TG_ARN=$(aws elbv2 describe-target-groups --names kfir-tg --query "TargetGroups[0].TargetGroupArn" --output text)
aws elbv2 describe-target-health --target-group-arn $TG_ARN

echo "---- RDS Instance Info ----"
aws rds describe-db-instances --db-instance-identifier KfirRdsInstance

echo "---- Security Group Info ----"
aws ec2 describe-security-groups --group-names KfirSecurityGroup2

echo "Script execution completed."
