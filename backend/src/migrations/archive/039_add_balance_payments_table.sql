-- Migration 039: Add balance_payments table to support multiple balance payments per credit record
-- This allows tracking multiple partial payments for a single credit record

CREATE TABLE IF NOT EXISTS company_purchase_balance_payments (
  id SERIAL PRIMARY KEY,
  purchase_id INTEGER NOT NULL REFERENCES company_purchase_details(id) ON DELETE CASCADE,
  balance_paid DECIMAL(10, 2) NOT NULL DEFAULT 0,
  balance_paid_date DATE,
  details TEXT,
  overall_balance DECIMAL(10, 2) NOT NULL DEFAULT 0, -- Calculated: previous overall_balance - balance_paid
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_balance_payments_purchase ON company_purchase_balance_payments(purchase_id);
CREATE INDEX IF NOT EXISTS idx_balance_payments_date ON company_purchase_balance_payments(balance_paid_date);

-- Add comment to table
COMMENT ON TABLE company_purchase_balance_payments IS 'Stores multiple balance payments for each company purchase credit record';

