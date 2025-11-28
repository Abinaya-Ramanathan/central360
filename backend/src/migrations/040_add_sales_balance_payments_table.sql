-- Migration 040: Add sales_balance_payments table to support multiple balance payments per sales credit record
-- This allows tracking multiple partial payments for a single sales credit record

CREATE TABLE IF NOT EXISTS sales_balance_payments (
  id SERIAL PRIMARY KEY,
  sale_id INTEGER NOT NULL REFERENCES sales_details(id) ON DELETE CASCADE,
  balance_paid DECIMAL(10, 2) NOT NULL DEFAULT 0,
  balance_paid_date DATE,
  details TEXT,
  overall_balance DECIMAL(10, 2) NOT NULL DEFAULT 0, -- Calculated: previous overall_balance - balance_paid
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_sales_balance_payments_sale ON sales_balance_payments(sale_id);
CREATE INDEX IF NOT EXISTS idx_sales_balance_payments_date ON sales_balance_payments(balance_paid_date);

-- Add comment to table
COMMENT ON TABLE sales_balance_payments IS 'Stores multiple balance payments for each sales credit record';

