# AWS Credentials Setup Guide

## Prerequisites
1. AWS CLI installed
2. AWS account with appropriate permissions

## Step 1: Install AWS CLI (if not installed)
```bash
# Windows (using PowerShell)
winget install -e --id Amazon.AWSCLI

# Or download from: https://aws.amazon.com/cli/
```

## Step 2: Configure AWS CLI
```bash
aws configure
```

You'll be prompted for:
- **AWS Access Key ID**: Your access key
- **AWS Secret Access Key**: Your secret key
- **Default region name**: `us-east-1`
- **Default output format**: `json`

## Step 3: Create IAM User (if needed)
1. Go to AWS Console → IAM
2. Create a new user with programmatic access
3. Attach these policies:
   - `AmazonEC2FullAccess`
   - `AmazonECSFullAccess`
   - `AmazonECRFullAccess`
   - `CloudWatchLogsFullAccess`
   - `IAMFullAccess` (for creating roles)

## Step 4: Run the Setup Script
```bash
# Make the script executable
chmod +x setup-aws-complete.sh

# Run the setup
./setup-aws-complete.sh
```

## Step 5: Add GitHub Secrets
1. Go to your GitHub repository
2. Settings → Secrets and variables → Actions
3. Add these secrets:
   - `AWS_ACCESS_KEY_ID`: Your AWS access key
   - `AWS_SECRET_ACCESS_KEY`: Your AWS secret key

## Step 6: Deploy
```bash
git add .
git commit -m "Add ECS deployment configuration"
git push origin main
```

## Troubleshooting
- If you get permission errors, ensure your IAM user has the required policies
- If resources already exist, the script will skip them
- Check CloudWatch logs for ECS service issues 