# ECS Platform Deployment Guide

This directory contains SAM CloudFormation templates for deploying your AWS DevOps Learning application on ECS with automated CI/CD pipeline.

## Templates Overview

### 1. `ecs-cluster.yaml`
Creates the ECS infrastructure:
- ECR repository for Docker images
- Uses existing **Default VPC** and its subnets (no new VPC created)
- Application Load Balancer
- ECS Fargate cluster
- ECS task definition and service
- CloudWatch log group
- Security groups and IAM roles

### 2. `codepipeline.yaml`
Creates the CI/CD pipeline:
- CodePipeline with GitHub integration
- CodeBuild project for Docker builds
- CodeDeploy for ECS deployments
- GitHub webhook for automatic triggers
- IAM roles and permissions

## Prerequisites

1. **AWS CLI** configured with appropriate permissions
2. **SAM CLI** installed
3. **GitHub Personal Access Token** with repo access
4. **Docker** installed locally (for testing)
5. **Default VPC** must exist in your AWS region (most regions have this by default)

## Deployment Steps

### Step 1: Deploy ECS Infrastructure

```bash
# Deploy the ECS cluster and related resources
# The script will automatically detect your default VPC and subnets
sam deploy \
  --template-file ecs-cluster.yaml \
  --stack-name aws-devops-learning-ecs-dev \
  --parameter-overrides \
    Environment=dev \
    AppName=aws-devops-learning-app \
    ImageTag=latest \
    DefaultVPCId=vpc-xxxxxxxxx \
    DefaultSubnet1Id=subnet-xxxxxxxxx \
    DefaultSubnet2Id=subnet-yyyyyyyyy \
  --capabilities CAPABILITY_IAM \
  --confirm-changeset
```

**Note**: You can get your default VPC and subnet IDs using:
```bash
# Get default VPC ID
aws ec2 describe-vpcs --filters "Name=is-default,Values=true" --query 'Vpcs[0].VpcId' --output text

# Get default subnets
aws ec2 describe-subnets --filters "Name=vpc-id,Values=vpc-xxxxxxxxx" "Name=default-for-az,Values=true" --query 'Subnets[].SubnetId' --output text
```

### Step 2: Store GitHub Token in Secrets Manager

```bash
# Store your GitHub personal access token
aws secretsmanager create-secret \
  --name "aws-devops-learning-dev-github-token" \
  --description "GitHub Personal Access Token for CodePipeline" \
  --secret-string "your-github-token-here"
```

### Step 3: Deploy CodePipeline

```bash
# Deploy the CI/CD pipeline
sam deploy \
  --template-file codepipeline.yaml \
  --stack-name aws-devops-learning-pipeline-dev \
  --parameter-overrides \
    Environment=dev \
    AppName=aws-devops-learning-app \
    GitHubOwner=faboulaye \
    GitHubRepo=aws-devops-learning \
    GitHubBranch=main \
    GitHubTokenSecretArn=arn:aws:secretsmanager:us-east-1:YOUR-ACCOUNT-ID:secret:aws-devops-learning-dev-github-token \
  --capabilities CAPABILITY_IAM \
  --confirm-changeset
```

### Step 4: Configure GitHub Webhook

After deployment, get the webhook URL and secret:

```bash
# Get webhook URL
aws cloudformation describe-stacks \
  --stack-name aws-devops-learning-pipeline-dev \
  --query 'Stacks[0].Outputs[?OutputKey==`WebhookURL`].OutputValue' \
  --output text

# Get webhook secret
aws secretsmanager get-secret-value \
  --secret-id aws-devops-learning-dev-github-webhook-secret \
  --query SecretString \
  --output text
```

Add the webhook to your GitHub repository:
1. Go to GitHub repo → Settings → Webhooks
2. Click "Add webhook"
3. Set Payload URL to the webhook URL from above
4. Set Content type to "application/json"
5. Set Secret to the webhook secret from above
6. Select "Just the push event"
7. Check "Active"
8. Click "Add webhook"

## Testing the Pipeline

1. **Create a release tag** to trigger the pipeline:
   ```bash
   git tag v1.0.1
   git push origin v1.0.1
   ```

2. **Monitor the pipeline** in AWS Console:
   - Go to CodePipeline → aws-devops-learning-dev-deployment-pipeline
   - Watch the stages: Source → Build → Deploy

3. **Check ECS service**:
   - Go to ECS → Clusters → aws-devops-learning-dev-cluster
   - Verify the service is running with the new image

4. **Test the application**:
   - Get the ALB DNS name from CloudFormation outputs
   - Visit `http://ALB-DNS-NAME` in your browser

## Environment Variables

The templates support these parameters:

### ECS Cluster Template
- `Environment`: dev/staging/prod
- `AppName`: Application name
- `ImageTag`: Docker image tag to deploy

### CodePipeline Template
- `Environment`: dev/staging/prod
- `AppName`: Application name
- `GitHubOwner`: GitHub username/organization
- `GitHubRepo`: Repository name
- `GitHubBranch`: Branch to monitor
- `GitHubTokenSecretArn`: ARN of GitHub token secret

## Cleanup

To remove all resources:

```bash
# Delete CodePipeline stack
aws cloudformation delete-stack --stack-name aws-devops-learning-pipeline-dev

# Delete ECS stack
aws cloudformation delete-stack --stack-name aws-devops-learning-ecs-dev

# Delete secrets
aws secretsmanager delete-secret \
  --secret-id aws-devops-learning-dev-github-token \
  --force-delete-without-recovery

aws secretsmanager delete-secret \
  --secret-id aws-devops-learning-dev-github-webhook-secret \
  --force-delete-without-recovery
```

## Troubleshooting

### Common Issues

1. **Pipeline fails at Source stage**:
   - Check GitHub token permissions
   - Verify webhook configuration
   - Ensure branch name matches

2. **Build fails**:
   - Check Dockerfile exists in repo root
   - Verify ECR repository exists
   - Check CodeBuild logs

3. **Deploy fails**:
   - Verify ECS cluster and service exist
   - Check CodeDeploy logs
   - Ensure task definition is valid

### Useful Commands

```bash
# Check pipeline status
aws codepipeline get-pipeline-state --name aws-devops-learning-dev-deployment-pipeline

# View build logs
aws logs describe-log-groups --log-group-name-prefix /aws/codebuild/aws-devops-learning-dev-docker-build

# Check ECS service status
aws ecs describe-services \
  --cluster aws-devops-learning-dev-cluster \
  --services aws-devops-learning-dev-service
```

## 🚀 Deployment Strategy Comparison

| Approach                                | Description                                                                                                                 | Pros                                           | Cons                                       | AWS Recommendation                       |
| --------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------- | ------------------------------------------ | ---------------------------------------- |
| **CodeDeployToECS (classic)**           | CodePipeline uses a **CodeDeploy** action with `appspec.yaml`, `taskdef.json`, and `imageDetail.json`.                      | Explicit control, mature, widely used          | More files & config to maintain            | ✅ Still supported, but considered legacy |
| **CloudFormation Blue/Green Hook**      | Deployments happen via **CloudFormation updates**, which internally trigger **CodeDeploy**.                                 | Simpler pipeline, fewer artifacts              | Less flexible, bound to stack updates      | ⚙️ Good for infra-as-code pipelines      |
| **ECS Native Blue/Green (recommended)** | **ECS** handles blue/green natively (no CodeDeploy) via **ECS Deployment Circuit Breaker** or new **ECS deployment types**. | Simplest, no CodeDeploy setup, faster rollback | Newer feature, may need ECS service update | 🟢 **Recommended by AWS (2025+)**        |
