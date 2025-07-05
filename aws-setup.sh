#!/bin/bash

# Replace these with your actual values
AWS_REGION="us-east-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "Setting up AWS resources for ECS deployment..."

# 1. Create ECR Repository
echo "Creating ECR repository..."
aws ecr create-repository --repository-name resume-website --region $AWS_REGION

# 2. Create CloudWatch Log Group
echo "Creating CloudWatch log group..."
aws logs create-log-group --log-group-name /ecs/resume-website --region $AWS_REGION

# 3. Create ECS Cluster
echo "Creating ECS cluster..."
aws ecs create-cluster --cluster-name resume-cluster --region $AWS_REGION

# 4. Create Task Execution Role (if it doesn't exist)
echo "Creating ECS task execution role..."
aws iam create-role \
    --role-name ecsTaskExecutionRole \
    --assume-role-policy-document '{
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
    }'

# Attach the required policies
aws iam attach-role-policy \
    --role-name ecsTaskExecutionRole \
    --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy

# 5. Update task definition with your account ID
sed -i "s/YOUR_ACCOUNT_ID/$ACCOUNT_ID/g" task-definition.json

# 6. Register Task Definition
echo "Registering task definition..."
aws ecs register-task-definition --cli-input-json file://task-definition.json --region $AWS_REGION

echo "Setup complete! Now you can:"
echo "1. Add AWS credentials to GitHub secrets"
echo "2. Push your code to trigger the workflow"
echo "3. Create ECS service in AWS Console or via CLI" 