#!/bin/bash

# Performance Test Script for Payment Consumer API
# Usage: ./load-test.sh [tool] [concurrency] [requests]
# Example: ./load-test.sh hey 10 1000

TOOL=${1:-hey}
CONCURRENCY=${2:-10}
REQUESTS=${3:-1000}
URL="http://localhost:8785/api/v1/consumer/payments"
PAYLOAD_FILE="payment-request.json"

echo "=========================================="
echo "Payment Consumer Performance Test"
echo "=========================================="
echo "Tool: $TOOL"
echo "Concurrency: $CONCURRENCY"
echo "Total Requests: $REQUESTS"
echo "URL: $URL"
echo "=========================================="
echo ""

case $TOOL in
  hey)
    echo "Running performance test with hey..."
    hey -n $REQUESTS -c $CONCURRENCY -m POST \
      -H "Content-Type: application/json" \
      -D $PAYLOAD_FILE \
      $URL
    ;;
    
  wrk)
    echo "Running performance test with wrk..."
    echo "Duration: 30 seconds"
    wrk -t$CONCURRENCY -c$CONCURRENCY -d30s \
      -s wrk-script.lua \
      $URL
    ;;
    
  ab)
    echo "Running performance test with Apache Bench..."
    ab -n $REQUESTS -c $CONCURRENCY \
      -p $PAYLOAD_FILE \
      -T "application/json" \
      $URL
    ;;
    
  k6)
    echo "Running performance test with k6..."
    k6 run load-test-k6.js
    ;;
    
  *)
    echo "Unknown tool: $TOOL"
    echo "Supported tools: hey, wrk, ab, k6"
    exit 1
    ;;
esac

echo ""
echo "=========================================="
echo "Test completed!"
echo "=========================================="
