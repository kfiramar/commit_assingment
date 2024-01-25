#!/bin/bash

# Set AWS configurations
AWS_REGION="eu-west-2"
ECR_REPO="533267130709.dkr.ecr.$AWS_REGION.amazonaws.com/nginx-commit"

# Step 1: Build and Push Docker Image to ECR
# Assumes Dockerfile is in the current directory
echo "Building and pushing Docker image to ECR..."
docker build -t nginx-commit .
docker tag nginx-commit:latest $ECR_REPO:latest
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REPO
docker push $ECR_REPO:latest

# Step 2: Update ECS Service
# Assumes aws cli is configured with necessary permissions
echo "Updating ECS Service..."
aws ecs update-service --cluster main-cluster --service nginx-service --force-new-deployment

echo "Deployment complete."