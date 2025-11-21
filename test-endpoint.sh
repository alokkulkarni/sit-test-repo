# Save this as test-endpoints.sh
#!/bin/bash

BASE_URL="https://testco20251121184146803400000008-155431973.eu-west-2.elb.amazonaws.com"
ENV="alok-sit-env"

echo "=== Testing Root ==="
curl -s -o /dev/null -w "%{http_code}\n" ${BASE_URL}/

echo -e "\n=== Testing Environment Path ==="
curl -s -o /dev/null -w "%{http_code}\n" ${BASE_URL}/${ENV}/

echo -e "\n=== Testing Beneficiaries Health ==="
curl -s -o /dev/null -w "%{http_code}\n" ${BASE_URL}/${ENV}/beneficiaries/actuator/health

echo -e "\n=== Testing without Environment Prefix ==="
curl -s -o /dev/null -w "%{http_code}\n" ${BASE_URL}/beneficiaries/actuator/health

echo -e "\n=== Testing Payments Health ==="
curl -s -o /dev/null -w "%{http_code}\n" ${BASE_URL}/${ENV}/payments/actuator/health

echo -e "\n=== Testing Consumer Health ==="
curl -s -o /dev/null -w "%{http_code}\n" ${BASE_URL}/${ENV}/consumer/actuator/health
