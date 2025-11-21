#!/bin/bash

REGION="eu-west-2"
LB_NAME="testco20251121184146803400000008"

echo "=== Finding Load Balancer ==="
LB_ARN=$(aws elbv2 describe-load-balancers \
  --region $REGION \
  --query "LoadBalancers[?contains(DNSName, '$LB_NAME')].LoadBalancerArn" \
  --output text)

echo "LB ARN: $LB_ARN"

echo -e "\n=== Target Groups ==="
aws elbv2 describe-target-groups \
  --load-balancer-arn $LB_ARN \
  --region $REGION \
  --query 'TargetGroups[].[TargetGroupName,Port,HealthCheckPath,Protocol]' \
  --output table

echo -e "\n=== Target Health ==="
TG_ARN=$(aws elbv2 describe-target-groups \
  --load-balancer-arn $LB_ARN \
  --region $REGION \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text)

aws elbv2 describe-target-health \
  --target-group-arn $TG_ARN \
  --region $REGION \
  --output table

echo -e "\n=== ALB Security Group ==="
aws elbv2 describe-load-balancers \
  --load-balancer-arn $LB_ARN \
  --region $REGION \
  --query 'LoadBalancers[0].SecurityGroups' \
  --output table

echo -e "\n=== Getting Target Instance Details ==="
TARGET_ID=$(aws elbv2 describe-target-health \
  --target-group-arn $TG_ARN \
  --region $REGION \
  --query 'TargetHealthDescriptions[0].Target.Id' \
  --output text)

echo "Target Instance ID: $TARGET_ID"

echo -e "\n=== EC2 Instance Security Groups ==="
aws ec2 describe-instances \
  --instance-ids $TARGET_ID \
  --region $REGION \
  --query 'Reservations[0].Instances[0].[InstanceId,State.Name,PrivateIpAddress,SecurityGroups[].GroupId]' \
  --output table

echo -e "\n=== EC2 Security Group Inbound Rules ==="
SG_ID=$(aws ec2 describe-instances \
  --instance-ids $TARGET_ID \
  --region $REGION \
  --query 'Reservations[0].Instances[0].SecurityGroups[0].GroupId' \
  --output text)

echo "Security Group: $SG_ID"
aws ec2 describe-security-groups \
  --group-ids $SG_ID \
  --region $REGION \
  --query 'SecurityGroups[0].IpPermissions[].[FromPort,ToPort,IpProtocol,IpRanges[].CidrIp,UserIdGroupPairs[].GroupId]' \
  --output table
