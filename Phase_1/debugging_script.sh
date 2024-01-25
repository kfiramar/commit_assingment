#!/bin/bash

set -e
set -x

KFIR_REGION=$(aws configure get region)
KFIR_VPC_NAME="KfirVPC"
KFIR_DB_SUBNET_GROUP_NAME="KfirDbSubnetGroup"

# Get the list of Availability Zones in the region
echo "Fetching Availability Zones in the region $KFIR_REGION..."
aws ec2 describe-availability-zones --region $KFIR_REGION --output table

# Get VPCs and their details
echo "Fetching details of VPCs..."
aws ec2 describe-vpcs --output table

# Get Subnets and their details
echo "Fetching details of Subnets..."
aws ec2 describe-subnets --output table

# Get RDS DB instance options for the region (focusing on t2.micro and MySQL)
echo "Fetching RDS DB instance options for db.t3.micro with MySQL engine..."
aws rds describe-orderable-db-instance-options --engine mysql --db-instance-class db.t3.micro --region $KFIR_REGION --output table

# Get details of the specific VPC
echo "Fetching details of VPC with the name $KFIR_VPC_NAME..."
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=$KFIR_VPC_NAME" --query "Vpcs[0].VpcId" --output text)
aws ec2 describe-vpcs --vpc-ids $VPC_ID --output table

# Get details of the specific DB Subnet Group
echo "Fetching details of DB Subnet Group with the name $KFIR_DB_SUBNET_GROUP_NAME..."
aws rds describe-db-subnet-groups --db-subnet-group-name $KFIR_DB_SUBNET_GROUP_NAME --output table

# Check for any recent RDS events that might indicate issues
echo "Fetching recent RDS events..."
aws rds describe-events --source-type db-instance --duration 720 --output table

echo "Debugging information collection complete."
