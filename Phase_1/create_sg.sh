#!/bin/bash

# Enable debugging
set -e
set -x

# Global Configurations
KFIR_VPC_NAME="KfirVPC"

# Function to retrieve VPC ID
get_vpc_id() {
    aws ec2 describe-vpcs --filters "Name=tag:Name,Values=$KFIR_VPC_NAME" --query "Vpcs[0].VpcId" --output text
}

# Function to create Security Group
create_security_group() {
    local vpc_id=$(get_vpc_id)
    local sg_name="KfirSecurityGroup2"
    local sg_description="Security Group for Kfirs RDS Instance"

    # Create security group
    sg_id=$(aws ec2 create-security-group --group-name "$sg_name" --description "$sg_description" --vpc-id $vpc_id --query 'GroupId' --output text)
    echo "Security Group Created: $sg_id"

    # Add inbound rule to allow MySQL traffic (modify as per your requirement)
    aws ec2 authorize-security-group-ingress --group-id $sg_id --protocol tcp --port 3306 --cidr 0.0.0.0/0
    echo "Inbound rules added to Security Group: $sg_id"

    # Add outbound rule (modify as per your requirement)
    aws ec2 authorize-security-group-egress --group-id $sg_id --protocol tcp --port 3306 --cidr 0.0.0.0/0
    echo "Outbound rules added to Security Group: $sg_id"

    echo $sg_id
}

# Call the function to create Security Group and capture its ID
KFIR_RDS_SECURITY_GROUP_ID=$(create_security_group)
echo "Created Security Group ID: $KFIR_RDS_SECURITY_GROUP_ID"
