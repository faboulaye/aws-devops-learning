#!/bin/bash

# ECS Platform Deployment Script
# This script deploys the ECS cluster and CodePipeline infrastructure

set -e

# Configuration
ENVIRONMENT=${1:-dev}
AWS_REGION=${AWS_REGION:-us-east-1}
GITHUB_OWNER=${GITHUB_OWNER:-faboulaye}
GITHUB_REPO=${GITHUB_REPO:-aws-devops-learning}
GITHUB_BRANCH=${GITHUB_BRANCH:-main}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed"
        exit 1
    fi
    
    # Check SAM CLI
    if ! command -v sam &> /dev/null; then
        log_error "SAM CLI is not installed"
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured"
        exit 1
    fi
    
    log_info "Prerequisites check passed"
}

get_account_id() {
    aws sts get-caller-identity --query Account --output text
}

create_github_token_secret() {
    local secret_name="aws-devops-learning-${ENVIRONMENT}-github-token"
    
    log_info "Creating GitHub token secret..."
    
    # Check if secret already exists
    if aws secretsmanager describe-secret --secret-id "$secret_name" &> /dev/null; then
        log_warn "GitHub token secret already exists: $secret_name"
        return
    fi
    
    # Prompt for GitHub token
    echo -n "Enter your GitHub Personal Access Token: "
    read -s github_token
    echo
    
    # Create secret
    aws secretsmanager create-secret \
        --name "$secret_name" \
        --description "GitHub Personal Access Token for CodePipeline" \
        --secret-string "$github_token" \
        --region "$AWS_REGION"
    
    log_info "GitHub token secret created: $secret_name"
}

get_default_vpc_info() {
    log_info "Getting default VPC and subnet information..."
    
    # Get default VPC ID
    local default_vpc_id=$(aws ec2 describe-vpcs \
        --filters "Name=is-default,Values=true" \
        --query 'Vpcs[0].VpcId' \
        --output text \
        --region "$AWS_REGION")
    
    if [ "$default_vpc_id" = "None" ] || [ -z "$default_vpc_id" ]; then
        log_error "No default VPC found in region $AWS_REGION"
        log_error "Please create a default VPC or specify VPC parameters manually"
        exit 1
    fi
    
    # Get default subnets
    local default_subnets=($(aws ec2 describe-subnets \
        --filters "Name=vpc-id,Values=$default_vpc_id" "Name=default-for-az,Values=true" \
        --query 'Subnets[].SubnetId' \
        --output text \
        --region "$AWS_REGION"))
    
    if [ ${#default_subnets[@]} -lt 2 ]; then
        log_error "Default VPC must have at least 2 subnets for ALB"
        exit 1
    fi
    
    DEFAULT_VPC_ID="$default_vpc_id"
    DEFAULT_SUBNET1_ID="${default_subnets[0]}"
    DEFAULT_SUBNET2_ID="${default_subnets[1]}"
    
    log_info "Using Default VPC: $DEFAULT_VPC_ID"
    log_info "Using Default Subnet 1: $DEFAULT_SUBNET1_ID"
    log_info "Using Default Subnet 2: $DEFAULT_SUBNET2_ID"
}

deploy_ecs_cluster() {
    local stack_name="aws-devops-learning-ecs-${ENVIRONMENT}"
    
    log_info "Deploying ECS cluster stack: $stack_name"
    
    sam deploy \
        --template-file ecs-cluster.yaml \
        --stack-name "$stack_name" \
        --parameter-overrides \
            Environment="$ENVIRONMENT" \
            AppName="aws-devops-learning-app" \
            ImageTag="latest" \
            DefaultVPCId="$DEFAULT_VPC_ID" \
            DefaultSubnet1Id="$DEFAULT_SUBNET1_ID" \
            DefaultSubnet2Id="$DEFAULT_SUBNET2_ID" \
        --capabilities CAPABILITY_IAM \
        --region "$AWS_REGION" \
        --confirm-changeset
    
    log_info "ECS cluster deployment completed"
}

deploy_codepipeline() {
    local stack_name="aws-devops-learning-pipeline-${ENVIRONMENT}"
    local account_id=$(get_account_id)
    local github_token_secret_arn="arn:aws:secretsmanager:${AWS_REGION}:${account_id}:secret:aws-devops-learning-${ENVIRONMENT}-github-token"
    
    log_info "Deploying CodePipeline stack: $stack_name"
    
    sam deploy \
        --template-file codepipeline.yaml \
        --stack-name "$stack_name" \
        --parameter-overrides \
            Environment="$ENVIRONMENT" \
            AppName="aws-devops-learning-app" \
            GitHubOwner="$GITHUB_OWNER" \
            GitHubRepo="$GITHUB_REPO" \
            GitHubBranch="$GITHUB_BRANCH" \
            GitHubTokenSecretArn="$github_token_secret_arn" \
        --capabilities CAPABILITY_IAM \
        --region "$AWS_REGION" \
        --confirm-changeset
    
    log_info "CodePipeline deployment completed"
}

get_webhook_info() {
    local stack_name="aws-devops-learning-pipeline-${ENVIRONMENT}"
    
    log_info "Getting webhook information..."
    
    # Get webhook URL
    local webhook_url=$(aws cloudformation describe-stacks \
        --stack-name "$stack_name" \
        --query 'Stacks[0].Outputs[?OutputKey==`WebhookURL`].OutputValue' \
        --output text \
        --region "$AWS_REGION")
    
    # Get webhook secret
    local webhook_secret=$(aws secretsmanager get-secret-value \
        --secret-id "aws-devops-learning-${ENVIRONMENT}-github-webhook-secret" \
        --query SecretString \
        --output text \
        --region "$AWS_REGION")
    
    echo
    log_info "GitHub Webhook Configuration:"
    echo "URL: $webhook_url"
    echo "Secret: $webhook_secret"
    echo
    log_warn "Please add this webhook to your GitHub repository:"
    log_warn "1. Go to GitHub repo → Settings → Webhooks"
    log_warn "2. Click 'Add webhook'"
    log_warn "3. Set Payload URL to: $webhook_url"
    log_warn "4. Set Secret to: $webhook_secret"
    log_warn "5. Select 'Just the push event'"
    log_warn "6. Check 'Active' and click 'Add webhook'"
}

get_application_url() {
    local stack_name="aws-devops-learning-ecs-${ENVIRONMENT}"
    
    log_info "Getting application URL..."
    
    local alb_dns=$(aws cloudformation describe-stacks \
        --stack-name "$stack_name" \
        --query 'Stacks[0].Outputs[?OutputKey==`ALBDNSName`].OutputValue' \
        --output text \
        --region "$AWS_REGION")
    
    echo
    log_info "Application URL: http://$alb_dns"
    log_warn "Note: It may take a few minutes for the ECS service to be ready"
}

main() {
    log_info "Starting ECS Platform deployment for environment: $ENVIRONMENT"
    
    check_prerequisites
    get_default_vpc_info
    create_github_token_secret
    deploy_ecs_cluster
    deploy_codepipeline
    get_webhook_info
    get_application_url
    
    log_info "Deployment completed successfully!"
    log_info "Next steps:"
    log_info "1. Configure the GitHub webhook as shown above"
    log_info "2. Create a release tag to trigger the pipeline:"
    log_info "   git tag v1.0.1 && git push origin v1.0.1"
    log_info "3. Monitor the pipeline in AWS Console"
}

# Run main function
main "$@"
