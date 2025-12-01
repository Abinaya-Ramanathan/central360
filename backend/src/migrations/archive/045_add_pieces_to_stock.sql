-- Add pieces columns to overall_stock table and update unit constraints to include 'pieces'

-- Add pieces columns to overall_stock
DO $$ BEGIN
  -- Add remaining_stock_pieces column
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'overall_stock' AND column_name = 'remaining_stock_pieces'
  ) THEN
    ALTER TABLE overall_stock 
    ADD COLUMN remaining_stock_pieces DECIMAL(10, 2) DEFAULT 0;
    
    COMMENT ON COLUMN overall_stock.remaining_stock_pieces IS 'Remaining stock quantity in pieces';
  END IF;

  -- Add new_stock_pieces column
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'overall_stock' AND column_name = 'new_stock_pieces'
  ) THEN
    ALTER TABLE overall_stock 
    ADD COLUMN new_stock_pieces DECIMAL(10, 2) DEFAULT 0;
    
    COMMENT ON COLUMN overall_stock.new_stock_pieces IS 'New stock quantity in pieces';
  END IF;
END $$;

-- Update unit constraint in daily_stock to include 'pieces'
DO $$ BEGIN
  -- Drop existing constraint if it exists
  ALTER TABLE daily_stock DROP CONSTRAINT IF EXISTS daily_stock_unit_check;
  
  -- Add new constraint with pieces
  ALTER TABLE daily_stock 
  ADD CONSTRAINT daily_stock_unit_check 
  CHECK (unit IN ('gram', 'kg', 'Litre', 'pieces') OR unit IS NULL);
END $$;

-- Update unit constraint in overall_stock to include 'pieces'
DO $$ BEGIN
  -- Drop existing constraint if it exists
  ALTER TABLE overall_stock DROP CONSTRAINT IF EXISTS overall_stock_unit_check;
  
  -- Add new constraint with pieces (if unit column exists)
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'overall_stock' AND column_name = 'unit'
  ) THEN
    ALTER TABLE overall_stock 
    DROP CONSTRAINT IF EXISTS overall_stock_unit_check;
    
    ALTER TABLE overall_stock 
    ADD CONSTRAINT overall_stock_unit_check 
    CHECK (unit IN ('gram', 'kg', 'Litre', 'pieces') OR unit IS NULL);
  END IF;
END $$;

-- Update unit constraint in daily_production to include 'pieces'
DO $$ BEGIN
  -- Drop existing constraint if it exists
  ALTER TABLE daily_production DROP CONSTRAINT IF EXISTS daily_production_unit_check;
  
  -- Add new constraint with pieces
  ALTER TABLE daily_production 
  ADD CONSTRAINT daily_production_unit_check 
  CHECK (unit IN ('gram', 'kg', 'Litre', 'pieces') OR unit IS NULL);
END $$;

