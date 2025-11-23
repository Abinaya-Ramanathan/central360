-- Create daily_production table
CREATE TABLE IF NOT EXISTS daily_production (
  id SERIAL PRIMARY KEY,
  product_name VARCHAR(255) NOT NULL,
  morning_production INTEGER NOT NULL DEFAULT 0,
  afternoon_production INTEGER NOT NULL DEFAULT 0,
  evening_production INTEGER NOT NULL DEFAULT 0,
  production_date DATE NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_daily_production_date ON daily_production(production_date);
CREATE INDEX IF NOT EXISTS idx_daily_production_product_date ON daily_production(product_name, production_date);

