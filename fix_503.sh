#!/bin/bash

# Define variables
ECS_CLUSTER="main-cluster"
ECS_SERVICE="nginx-service"
ECS_TASK_DEFINITION="nginx:8"

# Fetch the latest task ARN that stopped
echo "Fetching the latest stopped task ARN..."
latest_stopped_task=$(aws ecs list-tasks --cluster $ECS_CLUSTER --service-name $ECS_SERVICE --desired-status STOPPED --query 'taskArns' --output text | head -n 1)

if [ -z "$latest_stopped_task" ]; then
    echo "No stopped tasks found."
else
    # Fetch details of the latest stopped task
    echo "Fetching details for the stopped task: $latest_stopped_task"
    aws ecs describe-tasks --cluster $ECS_CLUSTER --tasks $latest_stopped_task --query 'tasks[*].{TaskArn:taskArn,StoppedReason:stoppedReason,Containers:containers[*].{Name:name,ExitCode:exitCode,Reason:reason}}' --output json
fi

# Check ECS service events
echo "Fetching ECS service events..."
aws ecs describe-services --cluster $ECS_CLUSTER --services $ECS_SERVICE --query 'services[*].events[0:5]' --output json

# Verify Execution Role Policy
echo "Verifying ECS Task Execution Role Policy..."
execution_role_name=$(aws iam list-roles --query "Roles[?RoleName=='ecs_execution_role'].RoleName" --output text)
if [ -z "$execution_role_name" ]; then
    echo "Execution role 'ecs_execution_role' not found."
else
    aws iam list-attached-role-policies --role-name "$execution_role_name" --query 'AttachedPolicies' --output json
fi
