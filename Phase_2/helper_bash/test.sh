#!/bin/bash

# Enable debugging
# set -e
set -x

# Global Configurations
KFIR_VPC_NAME="MainVPC"
KFIR_SUBNET1_NAME="Subnet1"
KFIR_SUBNET2_NAME="Subnet2"
KFIR_VPC_CIDR="10.0.0.0/16"
KFIR_SUBNET1_CIDR="10.0.1.0/24"
KFIR_SUBNET2_CIDR="10.0.2.0/24"
KFIR_ECS_CLUSTER_NAME="main-cluster" # Replace with your actual ECS Cluster name
KFIR_RDS_DB_INSTANCE="KfirRdsInstance"
KFIR_RDS_DB_NAME="kfirdb"
KFIR_DOCKER_IMAGE_NAME="nginx-kfir"
KFIR_REGION=$(aws configure get region)
KFIR_RDS_USERNAME="admin"
KFIR_RDS_PASSWORD="Passw0rd$2023" # Change this to a strong, unique password
KFIR_EXECUTION_ROLE_ARN="KfirEcsExecutionRole" # Replace with your actual ECS Task Execution Role ARN
KFIR_SECURITY_GROUP_NAME=KfirSecurityGroup2 # The name of the security group for RDS
KFIR_DB_SUBNET_GROUP_NAME="KfirDbSubnetGroup" # The name of the DB subnet group for RDS

# Function to retrieve VPC ID
get_vpc_id() {
    aws ec2 describe-vpcs --filters "Name=tag:Name,Values=$KFIR_VPC_NAME" --query "Vpcs[0].VpcId" --output text
}

# Function to retrieve Subnet IDs
get_subnet_id() {
    local subnet_name=$1
    aws ec2 describe-subnets --filters "Name=tag:Name,Values=$subnet_name" --query "Subnets[0].SubnetId" --output text
}

# Function to retrieve Security Group ID by Name
get_security_group_id() {
    local sg_name=$1
    aws ec2 describe-security-groups --filters "Name=group-name,Values=$sg_name" --query "SecurityGroups[0].GroupId" --output text
}

# Phase 1a: Create a VPC + 2 Subnets in different AZs
create_vpc_and_subnets() {
    echo "Creating VPC and Subnets..."
    VPC_ID=$(aws ec2 create-vpc --cidr-block $KFIR_VPC_CIDR --query 'Vpc.VpcId' --output text)
    aws ec2 create-tags --resources $VPC_ID --tags Key=Name,Value=$KFIR_VPC_NAME

    # Adjusted subnet creation to try including eu-west-1c
    SUBNET1_AZ="eu-west-1a"
    SUBNET2_AZ="eu-west-1c"

    SUBNET1_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block $KFIR_SUBNET1_CIDR --availability-zone $SUBNET1_AZ --query 'Subnet.SubnetId' --output text)
    aws ec2 create-tags --resources $SUBNET1_ID --tags Key=Name,Value=$KFIR_SUBNET1_NAME

    SUBNET2_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block $KFIR_SUBNET2_CIDR --availability-zone $SUBNET2_AZ --query 'Subnet.SubnetId' --output text)
    aws ec2 create-tags --resources $SUBNET2_ID --tags Key=Name,Value=$KFIR_SUBNET2_NAME
}

# Phase 1b: Configure Routes and limited NACLs
configure_routes_and_nacls() {
    echo "Configuring Routes and NACLs..."
    VPC_ID=$(get_vpc_id)
    IGW_ID=$(aws ec2 create-internet-gateway --query 'InternetGateway.InternetGatewayId' --output text)
    aws ec2 attach-internet-gateway --vpc-id $VPC_ID --internet-gateway-id $IGW_ID
    ROUTE_TABLE_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID --query 'RouteTable.RouteTableId' --output text)
    aws ec2 create-route --route-table-id $ROUTE_TABLE_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID
    SUBNET1_ID=$(get_subnet_id $KFIR_SUBNET1_NAME)
    SUBNET2_ID=$(get_subnet_id $KFIR_SUBNET2_NAME)
    aws ec2 associate-route-table --route-table-id $ROUTE_TABLE_ID --subnet-id $SUBNET1_ID
    aws ec2 associate-route-table --route-table-id $ROUTE_TABLE_ID --subnet-id $SUBNET2_ID
}


# Function to create a DB Subnet Group
create_db_subnet_group() {
    local subnet1_id=$(get_subnet_id $KFIR_SUBNET1_NAME)
    local subnet2_id=$(get_subnet_id $KFIR_SUBNET2_NAME)

    # Ensure that the subnets are in different AZs
    local subnet1_az=$(aws ec2 describe-subnets --subnet-ids $subnet1_id --query "Subnets[0].AvailabilityZone" --output text)
    local subnet2_az=$(aws ec2 describe-subnets --subnet-ids $subnet2_id --query "Subnets[0].AvailabilityZone" --output text)

    if [ "$subnet1_az" = "$subnet2_az" ]; then
        echo "Error: Subnets are in the same Availability Zone. Ensure they are in different AZs."
        exit 1
    fi

    # Check if the DB subnet group already exists
    if aws rds describe-db-subnet-groups --db-subnet-group-name $KFIR_DB_SUBNET_GROUP_NAME >/dev/null 2>&1; then
        echo "DB Subnet Group $KFIR_DB_SUBNET_GROUP_NAME already exists"
    else
        echo "Creating DB Subnet Group $KFIR_DB_SUBNET_GROUP_NAME"
        aws rds create-db-subnet-group \
            --db-subnet-group-name $KFIR_DB_SUBNET_GROUP_NAME \
            --db-subnet-group-description "Subnet group for Kfir's RDS Instance" \
            --subnet-ids "$subnet1_id" "$subnet2_id"
    fi
}

# Phase 1c: Create ECS cluster
create_ecs_cluster() {
    echo "Creating ECS Cluster..."
    aws ecs create-cluster --cluster-name $KFIR_ECS_CLUSTER_NAME
}

# Phase 1d: Docker container running NGINX
create_nginx_container() {
    echo "Creating Docker Container with NGINX..."
    # Create the Dockerfile
    cat > Dockerfile <<EOF
FROM nginx:latest
RUN echo 'Hello Kfir' > /usr/share/nginx/html/index.html
EOF

    # Build the Docker image
    docker build -t $KFIR_DOCKER_IMAGE_NAME .

    # Create ECR repository if it doesn't exist
    if ! aws ecr describe-repositories --repository-names $KFIR_DOCKER_IMAGE_NAME --region $KFIR_REGION >/dev/null 2>&1; then
        echo "Creating ECR repository: $KFIR_DOCKER_IMAGE_NAME"
        aws ecr create-repository --repository-name $KFIR_DOCKER_IMAGE_NAME --region $KFIR_REGION
    fi

    # Get ECR repository URI
    KFIR_ECR_REPO_URI=$(aws ecr describe-repositories --repository-names $KFIR_DOCKER_IMAGE_NAME --region $KFIR_REGION --query 'repositories[0].repositoryUri' --output text)
    
    # Tag Docker image
    docker tag $KFIR_DOCKER_IMAGE_NAME:latest $KFIR_ECR_REPO_URI:latest

    # Login to ECR
    aws ecr get-login-password --region $KFIR_REGION | docker login --username AWS --password-stdin $KFIR_ECR_REPO_URI

    # Push Docker image to ECR
    docker push $KFIR_ECR_REPO_URI:latest

    # Create ECS Task Definition
    cat > ecs-task-def.json <<EOF
{
  "family": "$KFIR_ECS_CLUSTER_NAME",
  "containerDefinitions": [
    {
      "name": "$KFIR_DOCKER_IMAGE_NAME",
      "image": "$KFIR_ECR_REPO_URI:latest",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 80,
          "hostPort": 80
        }
      ]
    }
  ],
  "executionRoleArn": "$KFIR_EXECUTION_ROLE_ARN",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512"
}
EOF
    TASK_DEF_ARN=$(aws ecs register-task-definition --cli-input-json file://ecs-task-def.json --query 'taskDefinition.taskDefinitionArn' --output text)

    echo "Task Definition ARN: $TASK_DEF_ARN"
}

# Phase 1e: Surfing the service, showing “Hello Kfir”
# This phase is covered by the Dockerfile in Phase 1d

# Phase 1f: Create RDS MySQL/PostgreSQL
create_rds_instance() {
    create_db_subnet_group
    local sg_id=$(get_security_group_id $KFIR_SECURITY_GROUP_NAME)

    # Modify these variables to test different configurations
    local instance_type="db.t3.micro"  # Options: db.t3.micro, db.t3.small, db.m5.large
    local storage_type="gp3"  # Options: gp3, gp3, io1, io2
    local allocated_storage=20  # Adjust storage size if necessary

    echo "Creating RDS Instance with Instance Type: $instance_type"
    aws rds create-db-instance \
        --db-instance-identifier $KFIR_RDS_DB_INSTANCE \
        --db-instance-class $instance_type \
        --engine mysql \
        --storage-type $storage_type \
        --allocated-storage $allocated_storage \
        --db-name $KFIR_RDS_DB_NAME \
        --master-username $KFIR_RDS_USERNAME \
        --master-user-password $KFIR_RDS_PASSWORD \
        --vpc-security-group-ids $sg_id \
        --db-subnet-group-name $KFIR_DB_SUBNET_GROUP_NAME
        

}

# Function to create and configure the Load Balancer
create_and_configure_load_balancer() {
    local SUBNET1_ID=$(get_subnet_id $KFIR_SUBNET1_NAME)
    local SUBNET2_ID=$(get_subnet_id $KFIR_SUBNET2_NAME)
    
    # Create Load Balancer
    lb_arn=$(aws elbv2 create-load-balancer --name kfir-lb --subnets $SUBNET1_ID $SUBNET2_ID --security-groups $(get_security_group_id $KFIR_SECURITY_GROUP_NAME) --query 'LoadBalancers[0].LoadBalancerArn' --output text)
    
    # Create a Target Group with the target type as 'ip'
    tg_arn=$(aws elbv2 create-target-group --name kfir-tg --protocol HTTP --port 80 --vpc-id $(get_vpc_id) --target-type ip --query 'TargetGroups[0].TargetGroupArn' --output text)
    
    # Create a Listener for the Load Balancer
    aws elbv2 create-listener --load-balancer-arn $lb_arn --protocol HTTP --port 80 --default-actions Type=forward,TargetGroupArn=$tg_arn

    echo "Load Balancer ARN: $lb_arn"
    echo "Target Group ARN: $tg_arn"
}


deploy_ecs_service() {
    tg_arn=$(aws elbv2 describe-target-groups --names kfir-tg --query 'TargetGroups[0].TargetGroupArn' --output text)

    if [ -z "$tg_arn" ]; then
        echo "Target Group ARN not found. Ensure the target group 'kfir-tg' exists."
        exit 1
    fi

    local subnet1_id=$(get_subnet_id "$KFIR_SUBNET1_NAME")
    local subnet2_id=$(get_subnet_id "$KFIR_SUBNET2_NAME")
    if [ -z "$subnet1_id" ] || [ -z "$subnet2_id" ]; then
        echo "Subnet IDs not found. Ensure the subnets exist and are tagged correctly."
        exit 1
    fi
    local subnets="$subnet1_id,$subnet2_id"

    local security_group=$(get_security_group_id "$KFIR_SECURITY_GROUP_NAME")
    if [ -z "$security_group" ]; then
        echo "Security group ID not found. Ensure the security group exists."
        exit 1
    fi

    aws ecs create-service --cluster "$KFIR_ECS_CLUSTER_NAME" \
        --service-name kfir-nginx-service \
        --task-definition "arn:aws:ecs:eu-west-1:533267130709:task-definition/KfirEcsCluster:6" \
        --load-balancers targetGroupArn=$tg_arn,containerName=$KFIR_DOCKER_IMAGE_NAME,containerPort=80 \
        --launch-type FARGATE \
        --network-configuration "awsvpcConfiguration={subnets=[$subnets],securityGroups=[$security_group],assignPublicIp=ENABLED}" \
        --desired-count 1
}

# ... rest of your script ...

# Call the deploy_ecs_service function
deploy_ecs_service


# Call the functions for the phases you want to execute
# Uncomment the lines below to run specific phases
# Main Execution
# create_vpc_and_subnets
# configure_routes_and_nacls
# create_ecs_cluster
# create_and_configure_load_balancer
# deploy_ecs_service
# create_nginx_container
# create_rds_instance
# configure_https

deploy_ecs_service

echo "Script Execution Completed"
