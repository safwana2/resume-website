#!/bin/bash

# AWS Configuration Script for ECS Deployment
# This script sets up all necessary AWS resources

set -e  # Exit on any error

# Configuration
AWS_REGION="us-east-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
CLUSTER_NAME="resume-cluster"
SERVICE_NAME="resume-service"
TASK_DEFINITION="resume-task-definition"
ECR_REPOSITORY="resume-website"

echo "🚀 Setting up AWS resources for ECS deployment..."
echo "Account ID: $ACCOUNT_ID"
echo "Region: $AWS_REGION"
echo ""

# 1. Create ECR Repository
echo "📦 Creating ECR repository..."
aws ecr create-repository \
    --repository-name $ECR_REPOSITORY \
    --region $AWS_REGION \
    --image-scanning-configuration scanOnPush=true \
    --encryption-configuration encryptionType=AES256 2>/dev/null || echo "Repository already exists"

# 2. Create CloudWatch Log Group
echo "📊 Creating CloudWatch log group..."
aws logs create-log-group \
    --log-group-name /ecs/$ECR_REPOSITORY \
    --region $AWS_REGION 2>/dev/null || echo "Log group already exists"

# 3. Create ECS Cluster
echo "🏗️ Creating ECS cluster..."
aws ecs create-cluster \
    --cluster-name $CLUSTER_NAME \
    --region $AWS_REGION \
    --capacity-providers FARGATE \
    --default-capacity-provider-strategy capacityProvider=FARGATE,weight=1 2>/dev/null || echo "Cluster already exists"

# 4. Create Task Execution Role
echo "🔐 Creating ECS task execution role..."
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
    }' 2>/dev/null || echo "Role already exists"

# Attach required policies
echo "📋 Attaching policies to execution role..."
aws iam attach-role-policy \
    --role-name ecsTaskExecutionRole \
    --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy 2>/dev/null || echo "Policy already attached"

# 5. Create Security Group
echo "🛡️ Creating security group..."
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=is-default,Values=true" --query 'Vpcs[0].VpcId' --output text --region $AWS_REGION)
SG_NAME="resume-website-sg"

SG_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=$SG_NAME" --query 'SecurityGroups[0].GroupId' --output text --region $AWS_REGION)

if [ "$SG_ID" == "None" ] || [ -z "$SG_ID" ]; then
    SG_ID=$(aws ec2 create-security-group \
        --group-name $SG_NAME \
        --description "Security group for resume website ECS service" \
        --vpc-id $VPC_ID \
        --region $AWS_REGION \
        --query 'GroupId' --output text)
    
    # Add inbound rule for HTTP
    aws ec2 authorize-security-group-ingress \
        --group-id $SG_ID \
        --protocol tcp \
        --port 80 \
        --cidr 0.0.0.0/0 \
        --region $AWS_REGION
    
    echo "Security group created: $SG_ID"
else
    echo "Security group already exists: $SG_ID"
fi

# 6. Update task definition with account ID
echo "📝 Updating task definition..."
sed -i "s/YOUR_ACCOUNT_ID/$ACCOUNT_ID/g" task-definition.json

# 7. Register Task Definition
echo "📋 Registering task definition..."
aws ecs register-task-definition \
    --cli-input-json file://task-definition.json \
    --region $AWS_REGION

# 8. Get subnets for service
echo "🌐 Getting network configuration..."
SUBNETS=$(aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$VPC_ID" "Name=map-public-ip-on-launch,Values=true" \
    --query 'Subnets[*].SubnetId' \
    --output text \
    --region $AWS_REGION)
SUBNET_LIST=$(echo $SUBNETS | tr ' ' ',' | sed 's/,$//')

# 9. Create ECS Service
echo "🚀 Creating ECS service..."
aws ecs create-service \
    --cluster $CLUSTER_NAME \
    --service-name $SERVICE_NAME \
    --task-definition $TASK_DEFINITION \
    --desired-count 1 \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_LIST],securityGroups=[$SG_ID],assignPublicIp=ENABLED}" \
    --region $AWS_REGION 2>/dev/null || echo "Service already exists"

echo ""
echo "✅ AWS setup complete!"
echo ""
echo "📋 Summary:"
echo "  ECR Repository: $ECR_REPOSITORY"
echo "  ECS Cluster: $CLUSTER_NAME"
echo "  ECS Service: $SERVICE_NAME"
echo "  Task Definition: $TASK_DEFINITION"
echo "  Security Group: $SG_ID"
echo "  Account ID: $ACCOUNT_ID"
echo ""
echo "🔑 Next steps:"
echo "1. Add these secrets to your GitHub repository:"
echo "   - AWS_ACCESS_KEY_ID"
echo "   - AWS_SECRET_ACCESS_KEY"
echo "2. Push your code to trigger the deployment workflow"
echo ""
echo "🌐 Your service will be available at the public IP assigned by ECS" 