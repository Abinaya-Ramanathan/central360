-- Migration 037: Add company_purchase_details table
-- This table stores company purchase information with credit tracking

CREATE TABLE IF NOT EXISTS company_purchase_details (
  id SERIAL PRIMARY KEY,
  sector_code VARCHAR(50) NOT NULL REFERENCES sectors(code) ON DELETE RESTRICT,
  name VARCHAR(255) NOT NULL,
  contact_number VARCHAR(50),
  address TEXT,
  product_name VARCHAR(255) NOT NULL, -- Can be string or integer
  quantity VARCHAR(255) NOT NULL, -- Can be string or integer
  amount_received DECIMAL(10, 2) DEFAULT 0,
  credit_amount DECIMAL(10, 2) DEFAULT 0,
  amount_pending DECIMAL(10, 2) DEFAULT 0, -- Calculated: credit_amount - amount_received
  balance_paid DECIMAL(10, 2) DEFAULT 0,
  balance_paid_date DATE,
  purchase_date DATE NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_company_purchase_details_sector ON company_purchase_details(sector_code);
CREATE INDEX IF NOT EXISTS idx_company_purchase_details_date ON company_purchase_details(purchase_date);
CREATE INDEX IF NOT EXISTS idx_company_purchase_details_name ON company_purchase_details(name);
CREATE INDEX IF NOT EXISTS idx_company_purchase_details_credit ON company_purchase_details(credit_amount) WHERE credit_amount > 0;

