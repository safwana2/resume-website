#!/bin/bash

# Configuration
AWS_REGION="us-east-1"
CLUSTER_NAME="resume-cluster"
SERVICE_NAME="resume-service"
TASK_DEFINITION="resume-task-definition"

echo "Creating ECS Service..."

# Get default VPC and subnets
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=is-default,Values=true" --query 'Vpcs[0].VpcId' --output text --region $AWS_REGION)
echo "Using VPC: $VPC_ID"

# Get public subnets
SUBNETS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" "Name=map-public-ip-on-launch,Values=true" --query 'Subnets[*].SubnetId' --output text --region $AWS_REGION)
SUBNET_LIST=$(echo $SUBNETS | tr ' ' ',' | sed 's/,$//')
echo "Using subnets: $SUBNET_LIST"

# Create security group for the service
SG_NAME="resume-website-sg"
SG_DESCRIPTION="Security group for resume website ECS service"

# Check if security group already exists
SG_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=$SG_NAME" --query 'SecurityGroups[0].GroupId' --output text --region $AWS_REGION)

if [ "$SG_ID" == "None" ] || [ -z "$SG_ID" ]; then
    echo "Creating security group..."
    SG_ID=$(aws ec2 create-security-group \
        --group-name $SG_NAME \
        --description "$SG_DESCRIPTION" \
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

# Create the ECS service
echo "Creating ECS service..."
aws ecs create-service \
    --cluster $CLUSTER_NAME \
    --service-name $SERVICE_NAME \
    --task-definition $TASK_DEFINITION \
    --desired-count 1 \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_LIST],securityGroups=[$SG_ID],assignPublicIp=ENABLED}" \
    --region $AWS_REGION

if [ $? -eq 0 ]; then
    echo "✅ ECS service created successfully!"
    echo "Service name: $SERVICE_NAME"
    echo "Cluster: $CLUSTER_NAME"
    echo "Security group: $SG_ID"
    echo ""
    echo "Next steps:"
    echo "1. Add AWS credentials to GitHub secrets"
    echo "2. Push your code to trigger the deployment workflow"
else
    echo "❌ Failed to create ECS service"
    exit 1
fi 