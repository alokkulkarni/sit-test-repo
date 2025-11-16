-- Payment Processor Test Database Initialization
-- This file is used by Testcontainers for integration and BDD tests

-- Drop table if exists
DROP TABLE IF EXISTS payments CASCADE;

-- Create payments table
CREATE TABLE payments (
    id BIGSERIAL PRIMARY KEY,
    transaction_id VARCHAR(255) NOT NULL UNIQUE,
    from_account VARCHAR(100) NOT NULL,
    to_account VARCHAR(100) NOT NULL,
    amount DECIMAL(19, 2) NOT NULL,
    currency VARCHAR(3) NOT NULL,
    payment_type VARCHAR(50) NOT NULL,
    status VARCHAR(50) NOT NULL,
    description TEXT,
    failure_reason TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for better query performance
CREATE INDEX idx_payments_transaction_id ON payments(transaction_id);
CREATE INDEX idx_payments_from_account ON payments(from_account);
CREATE INDEX idx_payments_to_account ON payments(to_account);
CREATE INDEX idx_payments_status ON payments(status);
CREATE INDEX idx_payments_created_at ON payments(created_at);

-- Insert test data for integration and BDD tests
INSERT INTO payments (transaction_id, from_account, to_account, amount, currency, payment_type, status, description, created_at, updated_at)
VALUES 
    ('TEST-TXN-001', 'ACC001', 'ACC002', 1000.00, 'USD', 'DOMESTIC_PAYMENT', 'COMPLETED', 'Test completed payment', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('TEST-TXN-002', 'ACC002', 'ACC003', 500.00, 'USD', 'DOMESTIC_TRANSFER', 'COMPLETED', 'Test transfer', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('TEST-TXN-003', 'ACC001', 'ACC004', 2000.00, 'USD', 'INTRABANK_TRANSFER', 'COMPLETED', 'Test intrabank transfer', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('TEST-TXN-004', 'ACC005', 'ACC002', 10000.00, 'USD', 'DOMESTIC_PAYMENT', 'INSUFFICIENT_BALANCE', 'Test failed - insufficient balance', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('TEST-TXN-005', 'ACC001', 'ACC001', 100.00, 'USD', 'DOMESTIC_PAYMENT', 'FRAUD_CHECK_FAILED', 'Test failed - fraud detected', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('TEST-TXN-006', 'INVALID001', 'ACC002', 500.00, 'USD', 'DOMESTIC_PAYMENT', 'ACCOUNT_VALIDATION_FAILED', 'Test failed - invalid account', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('TEST-TXN-007', 'ACC001', 'ACC003', 5000.00, 'USD', 'INTERBANK_TRANSFER', 'PROCESSING', 'Test processing payment', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('TEST-TXN-008', 'ACC002', 'ACC004', 750.00, 'USD', 'DOMESTIC_TRANSFER', 'PENDING', 'Test pending payment', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('TEST-TXN-009', 'ACC003', 'ACC005', 1500.00, 'USD', 'INTRABANK_TRANSFER', 'COMPLETED', 'Test completed transfer', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('TEST-TXN-010', 'ACC004', 'ACC001', 250.00, 'USD', 'DOMESTIC_PAYMENT', 'FAILED', 'Test failed payment', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

-- Comments for documentation
COMMENT ON TABLE payments IS 'Stores payment transaction records for testing';
COMMENT ON COLUMN payments.transaction_id IS 'Unique transaction identifier for testing';
