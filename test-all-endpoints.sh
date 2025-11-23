#!/bin/bash

# Test All Service Endpoints
# This script tests all REST endpoints for Beneficiaries, Payment Processor, and Payment Consumer services

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ALB_URL="${ALB_URL:-http://testco20251123175335691100000008-499535768.eu-west-2.elb.amazonaws.com}"
CUSTOMER_ID="${CUSTOMER_ID:-CUST001}"
ACCOUNT_NUMBER="${ACCOUNT_NUMBER:-1234567890}"
BENEFICIARY_ACCOUNT="${BENEFICIARY_ACCOUNT:-9876543210}"

# Counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Function to print section headers
print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

# Function to print test results
print_result() {
    local test_name=$1
    local status_code=$2
    local expected_code=$3
    local response=$4
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if [ "$status_code" -eq "$expected_code" ]; then
        echo -e "${GREEN}✓ PASS${NC} - $test_name (Status: $status_code)"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        if [ -n "$response" ]; then
            echo -e "  Response: ${response:0:200}..."
        fi
    else
        echo -e "${RED}✗ FAIL${NC} - $test_name (Expected: $expected_code, Got: $status_code)"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        if [ -n "$response" ]; then
            echo -e "  Response: $response"
        fi
    fi
    echo ""
}

# Function to make HTTP request and extract status code
make_request() {
    local method=$1
    local url=$2
    local data=$3
    local temp_file=$(mktemp)
    
    if [ -n "$data" ]; then
        curl -s -w "\n%{http_code}" -X "$method" "$url" \
            -H "Content-Type: application/json" \
            -d "$data" > "$temp_file" 2>&1
    else
        curl -s -w "\n%{http_code}" -X "$method" "$url" > "$temp_file" 2>&1
    fi
    
    local status_code=$(tail -n1 "$temp_file")
    local response=$(head -n -1 "$temp_file")
    
    rm -f "$temp_file"
    
    echo "$status_code"
    echo "$response"
}

# Store created resource IDs
BENEFICIARY_ID=""
TRANSACTION_ID=""

#############################################
# HEALTH CHECKS
#############################################
print_header "Health Check Endpoints"

result=$(make_request "GET" "$ALB_URL/dev/beneficiaries/actuator/health")
status_code=$(echo "$result" | head -n1)
response=$(echo "$result" | tail -n +2)
print_result "Beneficiaries Health Check" "$status_code" "200" "$response"

result=$(make_request "GET" "$ALB_URL/dev/paymentprocessor/actuator/health")
status_code=$(echo "$result" | head -n1)
response=$(echo "$result" | tail -n +2)
print_result "Payment Processor Health Check" "$status_code" "200" "$response"

result=$(make_request "GET" "$ALB_URL/dev/paymentconsumer/actuator/health")
status_code=$(echo "$result" | head -n1)
response=$(echo "$result" | tail -n +2)
print_result "Payment Consumer Health Check" "$status_code" "200" "$response"

#############################################
# BENEFICIARIES SERVICE
#############################################
print_header "Beneficiaries Service Endpoints"

# Create Beneficiary
echo -e "${YELLOW}Creating new beneficiary...${NC}"
result=$(make_request "POST" "$ALB_URL/dev/beneficiaries/api/v1/beneficiaries" '{
    "customerId": "'"$CUSTOMER_ID"'",
    "beneficiaryName": "John Doe",
    "accountNumber": "'"$BENEFICIARY_ACCOUNT"'",
    "bankName": "Test Bank",
    "ifscCode": "TEST0001234",
    "accountType": "SAVINGS"
}')
status_code=$(echo "$result" | head -n1)
response=$(echo "$result" | tail -n +2)
print_result "Create Beneficiary" "$status_code" "201" "$response"

# Extract beneficiary ID from response
if [ "$status_code" -eq "201" ]; then
    BENEFICIARY_ID=$(echo "$response" | grep -o '"id":[0-9]*' | grep -o '[0-9]*' | head -n1)
    if [ -n "$BENEFICIARY_ID" ]; then
        echo -e "  ${GREEN}Created Beneficiary ID: $BENEFICIARY_ID${NC}"
    fi
fi

# Get All Beneficiaries
result=$(make_request "GET" "$ALB_URL/dev/beneficiaries/api/v1/beneficiaries?customerId=$CUSTOMER_ID")
status_code=$(echo "$result" | head -n1)
response=$(echo "$result" | tail -n +2)
print_result "Get All Beneficiaries" "$status_code" "200" "$response"

# Get Beneficiaries by Account Number
result=$(make_request "GET" "$ALB_URL/dev/beneficiaries/api/v1/beneficiaries?customerId=$CUSTOMER_ID&accountNumber=$BENEFICIARY_ACCOUNT")
status_code=$(echo "$result" | head -n1)
response=$(echo "$result" | tail -n +2)
print_result "Get Beneficiaries by Account" "$status_code" "200" "$response"

# Get Specific Beneficiary (if ID was captured)
if [ -n "$BENEFICIARY_ID" ]; then
    result=$(make_request "GET" "$ALB_URL/dev/beneficiaries/api/v1/beneficiaries/$BENEFICIARY_ID?customerId=$CUSTOMER_ID")
    status_code=$(echo "$result" | head -n1)
    response=$(echo "$result" | tail -n +2)
    print_result "Get Specific Beneficiary" "$status_code" "200" "$response"
    
    # Update Beneficiary
    result=$(make_request "PUT" "$ALB_URL/dev/beneficiaries/api/v1/beneficiaries/$BENEFICIARY_ID?customerId=$CUSTOMER_ID" '{
        "customerId": "'"$CUSTOMER_ID"'",
        "beneficiaryName": "John Doe Updated",
        "accountNumber": "'"$BENEFICIARY_ACCOUNT"'",
        "bankName": "Updated Bank",
        "ifscCode": "UPDT0001234",
        "accountType": "CURRENT"
    }')
    status_code=$(echo "$result" | head -n1)
    response=$(echo "$result" | tail -n +2)
    print_result "Update Beneficiary" "$status_code" "200" "$response"
fi

#############################################
# PAYMENT PROCESSOR SERVICE
#############################################
print_header "Payment Processor Service Endpoints"

# Process Payment
echo -e "${YELLOW}Processing payment...${NC}"
result=$(make_request "POST" "$ALB_URL/dev/paymentprocessor/api/payments" '{
    "fromAccount": "'"$ACCOUNT_NUMBER"'",
    "toAccount": "'"$BENEFICIARY_ACCOUNT"'",
    "amount": 100.50,
    "currency": "USD",
    "description": "Test payment from SIT script"
}')
status_code=$(echo "$result" | head -n1)
response=$(echo "$result" | tail -n +2)
print_result "Process Payment" "$status_code" "200" "$response"

# Extract transaction ID from response
if [[ "$status_code" -eq "200" || "$status_code" -eq "201" ]]; then
    TRANSACTION_ID=$(echo "$response" | grep -o '"transactionId":"[^"]*"' | grep -o ':"[^"]*"' | grep -o '[^":]*' | head -n1)
    if [ -n "$TRANSACTION_ID" ]; then
        echo -e "  ${GREEN}Transaction ID: $TRANSACTION_ID${NC}"
    fi
fi

# Get All Payments
result=$(make_request "GET" "$ALB_URL/dev/paymentprocessor/api/payments")
status_code=$(echo "$result" | head -n1)
response=$(echo "$result" | tail -n +2)
print_result "Get All Payments" "$status_code" "200" "$response"

# Get Payments by Account
result=$(make_request "GET" "$ALB_URL/dev/paymentprocessor/api/payments/account/$ACCOUNT_NUMBER")
status_code=$(echo "$result" | head -n1)
response=$(echo "$result" | tail -n +2)
print_result "Get Payments by Account" "$status_code" "200" "$response"

# Get Payment Status (if transaction ID was captured)
if [ -n "$TRANSACTION_ID" ]; then
    result=$(make_request "GET" "$ALB_URL/dev/paymentprocessor/api/payments/$TRANSACTION_ID")
    status_code=$(echo "$result" | head -n1)
    response=$(echo "$result" | tail -n +2)
    print_result "Get Payment Status" "$status_code" "200" "$response"
fi

#############################################
# PAYMENT CONSUMER SERVICE
#############################################
print_header "Payment Consumer Service Endpoints"

# Get Account Details
result=$(make_request "GET" "$ALB_URL/dev/paymentconsumer/api/v1/consumer/accounts/$CUSTOMER_ID")
status_code=$(echo "$result" | head -n1)
response=$(echo "$result" | tail -n +2)
print_result "Get Account Details" "$status_code" "200" "$response"

# Get Beneficiaries (Consumer API)
result=$(make_request "GET" "$ALB_URL/dev/paymentconsumer/api/v1/consumer/beneficiaries?customerId=$CUSTOMER_ID")
status_code=$(echo "$result" | head -n1)
response=$(echo "$result" | tail -n +2)
print_result "Get Beneficiaries (Consumer)" "$status_code" "200" "$response"

# Get Beneficiaries with Account Filter
result=$(make_request "GET" "$ALB_URL/dev/paymentconsumer/api/v1/consumer/beneficiaries?customerId=$CUSTOMER_ID&accountNumber=$ACCOUNT_NUMBER")
status_code=$(echo "$result" | head -n1)
response=$(echo "$result" | tail -n +2)
print_result "Get Beneficiaries by Account (Consumer)" "$status_code" "200" "$response"

# Process Payment (Consumer API)
echo -e "${YELLOW}Processing payment via consumer API...${NC}"
result=$(make_request "POST" "$ALB_URL/dev/paymentconsumer/api/v1/consumer/payments" '{
    "customerId": "'"$CUSTOMER_ID"'",
    "fromAccount": "'"$ACCOUNT_NUMBER"'",
    "toAccount": "'"$BENEFICIARY_ACCOUNT"'",
    "amount": 250.75,
    "currency": "USD",
    "description": "Payment via consumer API test"
}')
status_code=$(echo "$result" | head -n1)
response=$(echo "$result" | tail -n +2)
# Consumer API returns 201 for successful payment
print_result "Process Payment (Consumer)" "$status_code" "201" "$response"

# Extract transaction ID from consumer response
CONSUMER_TRANSACTION_ID=""
if [[ "$status_code" -eq "200" || "$status_code" -eq "201" ]]; then
    CONSUMER_TRANSACTION_ID=$(echo "$response" | grep -o '"transactionId":"[^"]*"' | grep -o ':"[^"]*"' | grep -o '[^":]*' | head -n1)
    if [ -n "$CONSUMER_TRANSACTION_ID" ]; then
        echo -e "  ${GREEN}Consumer Transaction ID: $CONSUMER_TRANSACTION_ID${NC}"
    fi
fi

# Get Payment Status (Consumer API)
if [ -n "$CONSUMER_TRANSACTION_ID" ]; then
    result=$(make_request "GET" "$ALB_URL/dev/paymentconsumer/api/v1/consumer/payments/$CONSUMER_TRANSACTION_ID?customerId=$CUSTOMER_ID")
    status_code=$(echo "$result" | head -n1)
    response=$(echo "$result" | tail -n +2)
    print_result "Get Payment Status (Consumer)" "$status_code" "200" "$response"
fi

#############################################
# CLEANUP (Optional)
#############################################
print_header "Cleanup"

# Delete Beneficiary (if ID was captured)
if [ -n "$BENEFICIARY_ID" ]; then
    echo -e "${YELLOW}Cleaning up test beneficiary...${NC}"
    result=$(make_request "DELETE" "$ALB_URL/dev/beneficiaries/api/v1/beneficiaries/$BENEFICIARY_ID?customerId=$CUSTOMER_ID")
    status_code=$(echo "$result" | head -n1)
    response=$(echo "$result" | tail -n +2)
    print_result "Delete Beneficiary" "$status_code" "204" "$response"
fi

#############################################
# SUMMARY
#############################################
print_header "Test Summary"

echo -e "Total Tests:  ${BLUE}$TOTAL_TESTS${NC}"
echo -e "Passed:       ${GREEN}$PASSED_TESTS${NC}"
echo -e "Failed:       ${RED}$FAILED_TESTS${NC}"
echo ""

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some tests failed${NC}"
    exit 1
fi
