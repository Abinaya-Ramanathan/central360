-- Create products table
CREATE TABLE IF NOT EXISTS products (
  id SERIAL PRIMARY KEY,
  product_name VARCHAR(255) NOT NULL,
  sector_code VARCHAR(50) NOT NULL REFERENCES sectors(code) ON DELETE CASCADE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(product_name, sector_code)
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_products_sector ON products(sector_code);
CREATE INDEX IF NOT EXISTS idx_products_name ON products(product_name);

