#!/bin/bash

# Create ECS Service
aws ecs create-service \
    --cluster resume-cluster \
    --service-name resume-service \
    --task-definition resume-task-definition \
    --desired-count 1 \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={subnets=[subnet-12345678],securityGroups=[sg-12345678],assignPublicIp=ENABLED}" \
    --region us-east-1

echo "ECS service created successfully!" 