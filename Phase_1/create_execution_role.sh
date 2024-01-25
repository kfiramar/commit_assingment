#!/bin/bash

# Enable debugging
set -e
set -x

# Configuration
ROLE_NAME="KfirEcsExecutionRole"

# Create ECS Task Execution Role
create_execution_role() {
    # Check if the role already exists
    role_exists=$(aws iam get-role --role-name $ROLE_NAME --output text --query 'Role.RoleName' 2>/dev/null || true)
    if [ -z "$role_exists" ]; then
        # Create Role with trust relationship for ECS Tasks
        aws iam create-role --role-name $ROLE_NAME --assume-role-policy-document file://trust-policy.json
        echo "Role created: $ROLE_NAME"

        # Attach the AmazonECSTaskExecutionRolePolicy policy to the role
        aws iam attach-role-policy --role-name $ROLE_NAME --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy
        echo "AmazonECSTaskExecutionRolePolicy attached to the role"
    else
        echo "Role already exists: $ROLE_NAME"
    fi

    # Get the role ARN
    aws iam get-role --role-name $ROLE_NAME --query 'Role.Arn' --output text
}

# Create trust-policy.json file
cat > trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Execute the function to create the role and get the ARN
ROLE_ARN=$(create_execution_role)

echo "Execution Role ARN: $ROLE_ARN"
