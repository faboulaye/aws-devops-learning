# Blue/Green ECS Deployments with CodeDeploy

This guide explains how to deploy a containerized application to AWS ECS using a blue/green deployment strategy managed by AWS CodeDeploy and CodePipeline.

## Key Concepts for Blue/Green Deployment with CodeDeploy

- **Deployment Controller**: Your ECS service must use the `CODE_DEPLOY` deployment controller. This allows CodeDeploy to manage traffic shifting between the blue (current) and green (new) task sets.
- **Task Definitions**: Each deployment creates a new revision of your ECS task definition. CodeDeploy manages which revision is running in production.
- **Target Groups**: You need two target groups (blue and green) attached to your Application Load Balancer. CodeDeploy switches traffic between these during deployment.
- **AppSpec and TaskDef Templates**: CodeDeploy uses `appspec.yaml` and ECS task definition templates to know how to update your service.
- **IAM Roles**: Proper IAM roles are required for CodeDeploy, ECS, and CodePipeline to interact and manage resources.
- **Rollback and Health Checks**: CodeDeploy can automatically roll back deployments if health checks fail or errors occur.
- **Pipeline Integration**: CodePipeline automates the build, test, and deployment process, triggering CodeDeploy for blue/green releases.

## Prerequisites

- AWS CLI configured with appropriate permissions
- AWS SAM CLI installed
- Docker installed locally (for building images)
- GitHub repository and personal access token (for pipeline integration)
- Default VPC and subnets in your AWS account

## Folder Structure

- `ecs-platform/`: CloudFormation/SAM templates for ECS infrastructure and pipeline.
- `ecs-platform/code-deploy/`: CodeDeploy and pipeline templates, task/appspec templates, and configuration files.

## Deployment Steps

### 1. Deploy ECS Core Infrastructure

This sets up the ECS cluster, networking, IAM roles, and other foundational resources.

```bash
task ecs:core.deploy
```

### 2. Deploy ECS Task Definition

This deploys the ECS task definition and related resources.

```bash
task ecs:task.deploy
```

### 3. Deploy the Blue/Green Pipeline with CodeDeploy

This sets up the CodePipeline, CodeBuild, and CodeDeploy resources for blue/green deployments.

```bash
task ecs:blue-green-pipeline-codedeploy.deploy
```

## Useful AWS CLI Commands

Get your default VPC and subnet IDs:

```bash
aws ec2 describe-vpcs --filters "Name=is-default,Values=true" --query 'Vpcs[0].VpcId' --output text

aws ec2 describe-subnets --filters "Name=vpc-id,Values=<your-vpc-id>" "Name=default-for-az,Values=true" --query 'Subnets[].SubnetId' --output text
```

## Notes

- The pipeline will automatically build, push, and deploy your app using blue/green strategy.
- Make sure to update parameters in your `samconfig.yaml` or pass them via CLI as needed.
- Monitor deployments in the AWS Console under CodeDeploy and ECS for status and troubleshooting.

Do not specify the task definition revision in appspec.yaml.
Use <TASK_DEFINITION> instead.
CodeDeploy automatically creates a new task definition revision during each deployment and injects the correct ARN.
