-- Migration 038: Update company_purchase_details table structure and add photos support

-- First, create the photos table
CREATE TABLE IF NOT EXISTS company_purchase_photos (
  id SERIAL PRIMARY KEY,
  purchase_id INTEGER NOT NULL REFERENCES company_purchase_details(id) ON DELETE CASCADE,
  image_url VARCHAR(500) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_company_purchase_photos_purchase ON company_purchase_photos(purchase_id);

-- Now update the company_purchase_details table structure
DO $$
BEGIN
  -- Drop old columns if they exist (we'll recreate with new structure)
  -- Note: We'll keep the table and just add new columns, making old ones nullable
  
  -- Add new columns
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

  -- Make old columns nullable (they won't be used but we keep them for backward compatibility)
  ALTER TABLE company_purchase_details ALTER COLUMN name DROP NOT NULL;
  ALTER TABLE company_purchase_details ALTER COLUMN product_name DROP NOT NULL;
  ALTER TABLE company_purchase_details ALTER COLUMN quantity DROP NOT NULL;
  ALTER TABLE company_purchase_details ALTER COLUMN purchase_date DROP NOT NULL;
END $$;

