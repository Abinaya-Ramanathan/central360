-- Add 'Boxes' to unit constraints in daily_stock, overall_stock, and daily_production tables

-- Update unit constraint in daily_stock to include 'Boxes'
DO $$ BEGIN
  -- Drop existing constraint if it exists
  ALTER TABLE daily_stock DROP CONSTRAINT IF EXISTS daily_stock_unit_check;
  
  -- Add new constraint with Boxes
  ALTER TABLE daily_stock 
  ADD CONSTRAINT daily_stock_unit_check 
  CHECK (unit IN ('gram', 'kg', 'Litre', 'pieces', 'Boxes') OR unit IS NULL);
END $$;

-- Update unit constraint in overall_stock to include 'Boxes'
DO $$ BEGIN
  -- Drop existing constraint if it exists
  ALTER TABLE overall_stock DROP CONSTRAINT IF EXISTS overall_stock_unit_check;
  
  -- Add new constraint with Boxes (if unit column exists)
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'overall_stock' AND column_name = 'unit'
  ) THEN
    ALTER TABLE overall_stock 
    DROP CONSTRAINT IF EXISTS overall_stock_unit_check;
    
    ALTER TABLE overall_stock 
    ADD CONSTRAINT overall_stock_unit_check 
    CHECK (unit IN ('gram', 'kg', 'Litre', 'pieces', 'Boxes') OR unit IS NULL);
  END IF;
END $$;

-- Update unit constraint in daily_production to include 'Boxes'
DO $$ BEGIN
  -- Drop existing constraint if it exists
  ALTER TABLE daily_production DROP CONSTRAINT IF EXISTS daily_production_unit_check;
  
  -- Add new constraint with Boxes
  ALTER TABLE daily_production 
  ADD CONSTRAINT daily_production_unit_check 
  CHECK (unit IN ('gram', 'kg', 'Litre', 'pieces', 'Boxes') OR unit IS NULL);
END $$;

