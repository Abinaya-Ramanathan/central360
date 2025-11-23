-- Create credit_details table
CREATE TABLE IF NOT EXISTS credit_details (
  id SERIAL PRIMARY KEY,
  sector_code VARCHAR(50) NOT NULL REFERENCES sectors(code) ON DELETE CASCADE,
  name VARCHAR(255) NOT NULL,
  phone_number VARCHAR(50),
  address TEXT,
  purchase_details TEXT,
  credit_amount DECIMAL(10, 2) DEFAULT 0,
  amount_settled DECIMAL(10, 2) DEFAULT 0,
  credit_date DATE NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_credit_details_sector ON credit_details(sector_code);
CREATE INDEX IF NOT EXISTS idx_credit_details_date ON credit_details(credit_date);
CREATE INDEX IF NOT EXISTS idx_credit_details_name ON credit_details(name);

