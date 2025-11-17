import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

// Custom metrics
const errorRate = new Rate('errors');

// Test configuration
export const options = {
  stages: [
    { duration: '30s', target: 10 },  // Ramp up to 10 users
    { duration: '1m', target: 50 },   // Ramp up to 50 users
    { duration: '30s', target: 100 }, // Spike to 100 users
    { duration: '1m', target: 50 },   // Ramp down to 50 users
    { duration: '30s', target: 0 },   // Ramp down to 0 users
  ],
  thresholds: {
    http_req_duration: ['p(95)<500', 'p(99)<1000'], // 95% of requests under 500ms, 99% under 1s
    http_req_failed: ['rate<0.1'], // Error rate under 10%
    errors: ['rate<0.1'],
  },
};

const BASE_URL = 'http://localhost:8785';

export default function () {
  // Payment request payload
  const payload = JSON.stringify({
    customerId: 'CUST001',
    fromAccount: 'ACC001',
    toAccount: 'ACC002',
    amount: 100.50,
    currency: 'USD',
    paymentType: 'DOMESTIC_PAYMENT',
    description: 'Performance test payment'
  });

  const params = {
    headers: {
      'Content-Type': 'application/json',
    },
  };

  // Make payment request
  const response = http.post(`${BASE_URL}/api/v1/consumer/payments`, payload, params);

  // Check response
  const checkResult = check(response, {
    'status is 201 or 202': (r) => r.status === 201 || r.status === 202,
    'response has transactionId': (r) => r.json('transactionId') !== undefined,
    'response time < 1000ms': (r) => r.timings.duration < 1000,
  });

  // Track errors
  errorRate.add(!checkResult);

  // Optional: Query payment status
  if (response.status === 201 || response.status === 202) {
    const transactionId = response.json('transactionId');
    if (transactionId) {
      const statusResponse = http.get(
        `${BASE_URL}/api/v1/consumer/payments/${transactionId}?customerId=CUST001`,
        params
      );
      check(statusResponse, {
        'status query is 200': (r) => r.status === 200,
      });
    }
  }

  // Think time between requests
  sleep(1);
}
