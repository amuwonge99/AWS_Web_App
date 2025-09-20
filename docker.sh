#!/bin/bash
set -e  # Exit on error

ACCOUNT_ID=044260499053
REGION=eu-west-2
REPO_NAME=app-repo
CLUSTER_NAME=app-cluster
SERVICE_NAME=app-first-service

echo "Logging in to ECR..."
aws ecr get-login-password --region $REGION \
  | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com

echo "Building Docker image..."
docker build --platform linux/amd64 -t $REPO_NAME .
docker tag $REPO_NAME:latest $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$REPO_NAME:latest

echo "Pushing image to ECR..."
docker push $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$REPO_NAME:latest

echo "Redeploying ECS service..."
# Suppress JSON output for cleaner display
aws ecs update-service \
  --cluster $CLUSTER_NAME \
  --service $SERVICE_NAME \
  --force-new-deployment \
  --region $REGION \
  --output text > /dev/null

echo "Waiting for ECS tasks to become healthy..."
TARGET_GROUP_ARN=$(terraform output -raw target_group_arn)
while true; do
  HEALTHY=$(aws elbv2 describe-target-health \
    --target-group-arn $TARGET_GROUP_ARN \
    --region $REGION \
    --query 'TargetHealthDescriptions[?TargetHealth.State==`healthy`]|length(@)')
  
  if [ "$HEALTHY" -ge 1 ]; then
    break
  fi
  echo "  - ECS tasks not healthy yet, waiting 5s..."
  sleep 5
done

# Output clickable ALB URL
ALB_URL=$(terraform output -raw app_url)
echo -e "\n========================================="
echo "Your application is now ready at:"
echo "http://$ALB_URL"
echo "=========================================\n"
