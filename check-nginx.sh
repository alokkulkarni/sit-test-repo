#!/bin/bash
INSTANCE_ID="i-021f9c1d6fdab7b5d"
REGION="eu-west-2"

echo "=== Checking Nginx Status ==="
aws ssm send-command \
  --instance-ids $INSTANCE_ID \
  --region $REGION \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["sudo systemctl status nginx","echo --- NGINX CONFIG TEST ---","sudo nginx -t","echo --- LOCALHOST HEALTH CHECK ---","curl -I http://localhost/health 2>&1","echo --- LOCALHOST ROOT ---","curl -I http://localhost/ 2>&1","echo --- DOCKER CONTAINERS ---","docker ps --format \"table {{.Names}}\t{{.Status}}\t{{.Ports}}\""]' \
  --output json | jq -r '.Command.CommandId' > /tmp/cmd_id.txt

CMD_ID=$(cat /tmp/cmd_id.txt)
echo "Command ID: $CMD_ID"
echo "Waiting 5 seconds for command to execute..."
sleep 5

echo -e "\n=== Command Output ==="
aws ssm get-command-invocation \
  --command-id $CMD_ID \
  --instance-id $INSTANCE_ID \
  --region $REGION \
  --query 'StandardOutputContent' \
  --output text
