-- ============================================
-- Consolidated Incremental Updates (Migrations 003-051)
-- ============================================
-- This file consolidates all incremental updates from migrations 003-051
-- Use this for existing databases that need to be updated
-- For new installations, use 001_complete_schema.sql instead
-- ============================================

-- Migration 003: Add vehicle fields to stock_items
ALTER TABLE stock_items 
ADD COLUMN IF NOT EXISTS vehicle_type VARCHAR(255),
ADD COLUMN IF NOT EXISTS part_number VARCHAR(255);

-- Migration 032: Add maintenance_issue_photos table
CREATE TABLE IF NOT EXISTS maintenance_issue_photos (
  id SERIAL PRIMARY KEY,
  issue_id INTEGER NOT NULL REFERENCES maintenance_issues(id) ON DELETE CASCADE,
  image_url VARCHAR(500) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_maintenance_issue_photos_issue ON maintenance_issue_photos(issue_id);

-- Add image_url column to maintenance_issues for backward compatibility
DO $$ 
BEGIN 
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'maintenance_issues' AND column_name = 'image_url'
  ) THEN
    ALTER TABLE maintenance_issues ADD COLUMN image_url VARCHAR(500);
  END IF;
END $$;

-- Migration 033: Add sales_details table
CREATE TABLE IF NOT EXISTS sales_details (
  id SERIAL PRIMARY KEY,
  sector_code VARCHAR(50) NOT NULL REFERENCES sectors(code) ON DELETE RESTRICT,
  name VARCHAR(255) NOT NULL,
  contact_number VARCHAR(50),
  address TEXT,
  product_name VARCHAR(255) NOT NULL,
  quantity VARCHAR(255) NOT NULL,
  amount_received DECIMAL(10, 2) DEFAULT 0,
  credit_amount DECIMAL(10, 2) DEFAULT 0,
  amount_pending DECIMAL(10, 2) DEFAULT 0,
  sale_date DATE NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_sales_details_sector ON sales_details(sector_code);
CREATE INDEX IF NOT EXISTS idx_sales_details_date ON sales_details(sale_date);
CREATE INDEX IF NOT EXISTS idx_sales_details_name ON sales_details(name);
CREATE INDEX IF NOT EXISTS idx_sales_details_credit ON sales_details(credit_amount) WHERE credit_amount > 0;

-- Migration 034: Add balance_paid to sales_details
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'sales_details' AND column_name = 'balance_paid'
  ) THEN
    ALTER TABLE sales_details ADD COLUMN balance_paid DECIMAL(10, 2) DEFAULT 0;
  END IF;
END $$;

-- Migration 035: Add balance_paid_date to sales_details
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'sales_details' AND column_name = 'balance_paid_date'
  ) THEN
    ALTER TABLE sales_details ADD COLUMN balance_paid_date DATE;
  END IF;
END $$;

-- Migration 036: Add bulk_advance columns to attendance
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'attendance' AND column_name = 'bulk_advance_taken'
  ) THEN
    ALTER TABLE attendance ADD COLUMN bulk_advance_taken DECIMAL(10, 2) DEFAULT 0;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'attendance' AND column_name = 'bulk_advance_paid'
  ) THEN
    ALTER TABLE attendance ADD COLUMN bulk_advance_paid DECIMAL(10, 2) DEFAULT 0;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'attendance' AND column_name = 'bulk_advance'
  ) THEN
    ALTER TABLE attendance ADD COLUMN bulk_advance DECIMAL(10, 2) DEFAULT 0;
  END IF;
END $$;

-- Migration 037: Add company_purchase_details table
CREATE TABLE IF NOT EXISTS company_purchase_details (
  id SERIAL PRIMARY KEY,
  sector_code VARCHAR(50) NOT NULL REFERENCES sectors(code) ON DELETE RESTRICT,
  name VARCHAR(255),
  contact_number VARCHAR(50),
  address TEXT,
  product_name VARCHAR(255),
  quantity VARCHAR(255),
  amount_received DECIMAL(10, 2) DEFAULT 0,
  credit_amount DECIMAL(10, 2) DEFAULT 0,
  amount_pending DECIMAL(10, 2) DEFAULT 0,
  balance_paid DECIMAL(10, 2) DEFAULT 0,
  balance_paid_date DATE,
  purchase_date DATE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_company_purchase_details_sector ON company_purchase_details(sector_code);
CREATE INDEX IF NOT EXISTS idx_company_purchase_details_date ON company_purchase_details(purchase_date);
CREATE INDEX IF NOT EXISTS idx_company_purchase_details_name ON company_purchase_details(name);
CREATE INDEX IF NOT EXISTS idx_company_purchase_details_credit ON company_purchase_details(credit_amount) WHERE credit_amount > 0;

-- Migration 038: Update company_purchase_details and add photos
CREATE TABLE IF NOT EXISTS company_purchase_photos (
  id SERIAL PRIMARY KEY,
  purchase_id INTEGER NOT NULL REFERENCES company_purchase_details(id) ON DELETE CASCADE,
  image_url VARCHAR(500) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_company_purchase_photos_purchase ON company_purchase_photos(purchase_id);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'company_purchase_details' AND column_name = 'item_name'
  ) THEN
    ALTER TABLE company_purchase_details ADD COLUMN item_name VARCHAR(255);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'company_purchase_details' AND column_name = 'shop_name'
  ) THEN
    ALTER TABLE company_purchase_details ADD COLUMN shop_name VARCHAR(255);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'company_purchase_details' AND column_name = 'purchase_details'
  ) THEN
    ALTER TABLE company_purchase_details ADD COLUMN purchase_details TEXT;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'company_purchase_details' AND column_name = 'purchase_amount'
  ) THEN
    ALTER TABLE company_purchase_details ADD COLUMN purchase_amount DECIMAL(10, 2) DEFAULT 0;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'company_purchase_details' AND column_name = 'amount_paid'
  ) THEN
    ALTER TABLE company_purchase_details ADD COLUMN amount_paid DECIMAL(10, 2) DEFAULT 0;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'company_purchase_details' AND column_name = 'credit'
  ) THEN
    ALTER TABLE company_purchase_details ADD COLUMN credit DECIMAL(10, 2) DEFAULT 0;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'company_purchase_details' AND column_name = 'details'
  ) THEN
    ALTER TABLE company_purchase_details ADD COLUMN details TEXT;
  END IF;

  -- Make old columns nullable
  ALTER TABLE company_purchase_details ALTER COLUMN name DROP NOT NULL;
  ALTER TABLE company_purchase_details ALTER COLUMN product_name DROP NOT NULL;
  ALTER TABLE company_purchase_details ALTER COLUMN quantity DROP NOT NULL;
  ALTER TABLE company_purchase_details ALTER COLUMN purchase_date DROP NOT NULL;
END $$;

-- Migration 039: Add company_purchase_balance_payments table
CREATE TABLE IF NOT EXISTS company_purchase_balance_payments (
  id SERIAL PRIMARY KEY,
  purchase_id INTEGER NOT NULL REFERENCES company_purchase_details(id) ON DELETE CASCADE,
  balance_paid DECIMAL(10, 2) NOT NULL DEFAULT 0,
  balance_paid_date DATE,
  details TEXT,
  overall_balance DECIMAL(10, 2) NOT NULL DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_balance_payments_purchase ON company_purchase_balance_payments(purchase_id);
CREATE INDEX IF NOT EXISTS idx_balance_payments_date ON company_purchase_balance_payments(balance_paid_date);

-- Migration 040: Add sales_balance_payments table
CREATE TABLE IF NOT EXISTS sales_balance_payments (
  id SERIAL PRIMARY KEY,
  sale_id INTEGER NOT NULL REFERENCES sales_details(id) ON DELETE CASCADE,
  balance_paid DECIMAL(10, 2) NOT NULL DEFAULT 0,
  balance_paid_date DATE,
  details TEXT,
  overall_balance DECIMAL(10, 2) NOT NULL DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_sales_balance_payments_sale ON sales_balance_payments(sale_id);
CREATE INDEX IF NOT EXISTS idx_sales_balance_payments_date ON sales_balance_payments(balance_paid_date);

-- Migration 041: Add details to sales_details
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'sales_details' AND column_name = 'details'
    ) THEN
        ALTER TABLE sales_details ADD COLUMN details TEXT;
    END IF;
END $$;

-- Migration 042: Add sector_code to daily_production
DO $$ 
DECLARE
  constraint_name TEXT;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'daily_production' AND column_name = 'sector_code'
  ) THEN
    ALTER TABLE daily_production 
    ADD COLUMN sector_code VARCHAR(50) REFERENCES sectors(code) ON DELETE CASCADE;
    
    CREATE INDEX IF NOT EXISTS idx_daily_production_sector ON daily_production(sector_code);
    
    -- Update unique constraint
    FOR constraint_name IN
      SELECT conname FROM pg_constraint 
      WHERE conrelid = 'daily_production'::regclass 
      AND contype = 'u'
      AND array_length(conkey, 1) = 2
    LOOP
      EXECUTE 'ALTER TABLE daily_production DROP CONSTRAINT IF EXISTS ' || constraint_name;
    END LOOP;
    
    IF NOT EXISTS (
      SELECT 1 FROM pg_constraint 
      WHERE conname = 'daily_production_product_sector_date_unique'
    ) THEN
      ALTER TABLE daily_production 
      ADD CONSTRAINT daily_production_product_sector_date_unique 
      UNIQUE(product_name, sector_code, production_date);
    END IF;
  END IF;
END $$;

-- Migration 043: Add unit columns to daily_stock, overall_stock, and daily_production
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'daily_stock' AND column_name = 'unit'
  ) THEN
    ALTER TABLE daily_stock 
    ADD COLUMN unit VARCHAR(20) CHECK (unit IN ('gram', 'kg', 'Litre') OR unit IS NULL);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'overall_stock' AND column_name = 'unit'
  ) THEN
    ALTER TABLE overall_stock 
    ADD COLUMN unit VARCHAR(20) CHECK (unit IN ('gram', 'kg', 'Litre') OR unit IS NULL);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'daily_production' AND column_name = 'unit'
  ) THEN
    ALTER TABLE daily_production 
    ADD COLUMN unit VARCHAR(20) CHECK (unit IN ('gram', 'kg', 'Litre') OR unit IS NULL);
  END IF;
END $$;

-- Migration 044: Add unit-specific columns to overall_stock
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'overall_stock' AND column_name = 'remaining_stock_gram'
  ) THEN
    ALTER TABLE overall_stock 
    ADD COLUMN remaining_stock_gram DECIMAL(10, 2) DEFAULT 0,
    ADD COLUMN remaining_stock_kg DECIMAL(10, 2) DEFAULT 0,
    ADD COLUMN remaining_stock_litre DECIMAL(10, 2) DEFAULT 0;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'overall_stock' AND column_name = 'new_stock_gram'
  ) THEN
    ALTER TABLE overall_stock 
    ADD COLUMN new_stock_gram DECIMAL(10, 2) DEFAULT 0,
    ADD COLUMN new_stock_kg DECIMAL(10, 2) DEFAULT 0,
    ADD COLUMN new_stock_litre DECIMAL(10, 2) DEFAULT 0;
  END IF;
END $$;

-- Migration 045: Add pieces columns to overall_stock and update unit constraints
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'overall_stock' AND column_name = 'remaining_stock_pieces'
  ) THEN
    ALTER TABLE overall_stock 
    ADD COLUMN remaining_stock_pieces DECIMAL(10, 2) DEFAULT 0;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'overall_stock' AND column_name = 'new_stock_pieces'
  ) THEN
    ALTER TABLE overall_stock 
    ADD COLUMN new_stock_pieces DECIMAL(10, 2) DEFAULT 0;
  END IF;
END $$;

-- Update unit constraints to include 'pieces'
DO $$ BEGIN
  ALTER TABLE daily_stock DROP CONSTRAINT IF EXISTS daily_stock_unit_check;
  ALTER TABLE daily_stock 
  ADD CONSTRAINT daily_stock_unit_check 
  CHECK (unit IN ('gram', 'kg', 'Litre', 'pieces') OR unit IS NULL);
END $$;

DO $$ BEGIN
  ALTER TABLE overall_stock DROP CONSTRAINT IF EXISTS overall_stock_unit_check;
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'overall_stock' AND column_name = 'unit'
  ) THEN
    ALTER TABLE overall_stock 
    ADD CONSTRAINT overall_stock_unit_check 
    CHECK (unit IN ('gram', 'kg', 'Litre', 'pieces') OR unit IS NULL);
  END IF;
END $$;

DO $$ BEGIN
  ALTER TABLE daily_production DROP CONSTRAINT IF EXISTS daily_production_unit_check;
  ALTER TABLE daily_production 
  ADD CONSTRAINT daily_production_unit_check 
  CHECK (unit IN ('gram', 'kg', 'Litre', 'pieces') OR unit IS NULL);
END $$;

-- Migration 046: Update unit constraints to include 'Boxes'
DO $$ BEGIN
  ALTER TABLE daily_stock DROP CONSTRAINT IF EXISTS daily_stock_unit_check;
  ALTER TABLE daily_stock 
  ADD CONSTRAINT daily_stock_unit_check 
  CHECK (unit IN ('gram', 'kg', 'Litre', 'pieces', 'Boxes') OR unit IS NULL);
END $$;

DO $$ BEGIN
  ALTER TABLE overall_stock DROP CONSTRAINT IF EXISTS overall_stock_unit_check;
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'overall_stock' AND column_name = 'unit'
  ) THEN
    ALTER TABLE overall_stock 
    ADD CONSTRAINT overall_stock_unit_check 
    CHECK (unit IN ('gram', 'kg', 'Litre', 'pieces', 'Boxes') OR unit IS NULL);
  END IF;
END $$;

DO $$ BEGIN
  ALTER TABLE daily_production DROP CONSTRAINT IF EXISTS daily_production_unit_check;
  ALTER TABLE daily_production 
  ADD CONSTRAINT daily_production_unit_check 
  CHECK (unit IN ('gram', 'kg', 'Litre', 'pieces', 'Boxes') OR unit IS NULL);
END $$;

-- Migration 047: Add boxes columns to overall_stock
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'overall_stock' AND column_name = 'remaining_stock_boxes'
  ) THEN
    ALTER TABLE overall_stock 
    ADD COLUMN remaining_stock_boxes DECIMAL(10, 2) DEFAULT 0;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'overall_stock' AND column_name = 'new_stock_boxes'
  ) THEN
    ALTER TABLE overall_stock 
    ADD COLUMN new_stock_boxes DECIMAL(10, 2) DEFAULT 0;
  END IF;
END $$;

-- ============================================
-- Migration 048: Add details column to mahal_bookings
-- ============================================
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'mahal_bookings' AND column_name = 'details'
  ) THEN
    ALTER TABLE mahal_bookings ADD COLUMN details TEXT;
    COMMENT ON COLUMN mahal_bookings.details IS 'Additional details for the mahal booking';
  END IF;
END $$;

-- ============================================
-- Migration 049: Create mahal_vessels table
-- ============================================
CREATE TABLE IF NOT EXISTS mahal_vessels (
  id SERIAL PRIMARY KEY,
  mahal_detail VARCHAR(255) NOT NULL CHECK (mahal_detail IN ('Thanthondrimalai Mini hall', 'Thirukampuliyur Minihall', 'Thirukampuliyur Big Hall')),
  item_name VARCHAR(255) NOT NULL,
  count INTEGER NOT NULL DEFAULT 1,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_mahal_vessels_mahal_detail ON mahal_vessels(mahal_detail);
CREATE INDEX IF NOT EXISTS idx_mahal_vessels_item_name ON mahal_vessels(item_name);

-- ============================================
-- Migration 050: Create rent_vehicles and rent_vehicle_attendance tables
-- ============================================
CREATE TABLE IF NOT EXISTS rent_vehicles (
  id SERIAL PRIMARY KEY,
  vehicle_name VARCHAR(255) NOT NULL,
  sector_code VARCHAR(50) NOT NULL REFERENCES sectors(code) ON DELETE RESTRICT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(vehicle_name, sector_code)
);

CREATE INDEX IF NOT EXISTS idx_rent_vehicles_sector_code ON rent_vehicles(sector_code);
CREATE INDEX IF NOT EXISTS idx_rent_vehicles_vehicle_name ON rent_vehicles(vehicle_name);

CREATE TABLE IF NOT EXISTS rent_vehicle_attendance (
  id SERIAL PRIMARY KEY,
  vehicle_id INTEGER NOT NULL REFERENCES rent_vehicles(id) ON DELETE CASCADE,
  vehicle_name VARCHAR(255) NOT NULL,
  sector VARCHAR(50) NOT NULL,
  date DATE NOT NULL,
  status VARCHAR(20) NOT NULL CHECK (status IN ('present', 'absent', 'halfday')),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(vehicle_id, date)
);

CREATE INDEX IF NOT EXISTS idx_rent_vehicle_attendance_vehicle_id ON rent_vehicle_attendance(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_rent_vehicle_attendance_date ON rent_vehicle_attendance(date);
CREATE INDEX IF NOT EXISTS idx_rent_vehicle_attendance_sector ON rent_vehicle_attendance(sector);

-- ============================================
-- Migration 051: Create ingredient_menus and ingredient_items tables
-- ============================================
CREATE TABLE IF NOT EXISTS ingredient_menus (
  id SERIAL PRIMARY KEY,
  menu VARCHAR(255) NOT NULL UNIQUE,
  members_count INTEGER NOT NULL DEFAULT 1,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_ingredient_menus_menu ON ingredient_menus(menu);

CREATE TABLE IF NOT EXISTS ingredient_items (
  id SERIAL PRIMARY KEY,
  menu_id INTEGER NOT NULL REFERENCES ingredient_menus(id) ON DELETE CASCADE,
  ingredient_name VARCHAR(255) NOT NULL,
  quantity DECIMAL(10, 3) NOT NULL,
  unit VARCHAR(50) NOT NULL CHECK (unit IN ('Litre', 'Gram', 'Kilogram', 'Pieces', 'ml')),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_ingredient_items_menu_id ON ingredient_items(menu_id);
CREATE INDEX IF NOT EXISTS idx_ingredient_items_ingredient_name ON ingredient_items(ingredient_name);

