-- Migration 033: Add sales_details table
-- This table stores sales information with credit tracking

CREATE TABLE IF NOT EXISTS sales_details (
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
  sale_date DATE NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_sales_details_sector ON sales_details(sector_code);
CREATE INDEX IF NOT EXISTS idx_sales_details_date ON sales_details(sale_date);
CREATE INDEX IF NOT EXISTS idx_sales_details_name ON sales_details(name);
CREATE INDEX IF NOT EXISTS idx_sales_details_credit ON sales_details(credit_amount) WHERE credit_amount > 0;

