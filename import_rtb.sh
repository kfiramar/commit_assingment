#!/bin/bash

# Set your subnet and AWS region here
subnet_id="subnet-097c6a242ba457e7f"
aws_region="eu-west-1"

# Find the route table association ID for the subnet
association_id=$(aws ec2 describe-route-tables --region $aws_region \
                  --query "RouteTables[].Associations[?SubnetId=='$subnet_id'].RouteTableAssociationId" \
                  --output text)

# Check if we found a valid association
if [ "$association_id" == "None" ] || [ -z "$association_id" ]; then
  echo "No association found for subnet $subnet_id."
  exit 1
else
  echo "Found association: $association_id"
fi

# Import the association into Terraform
echo "Importing association into Terraform..."
terraform import aws_route_table_association.b $subnet_id/$association_id
