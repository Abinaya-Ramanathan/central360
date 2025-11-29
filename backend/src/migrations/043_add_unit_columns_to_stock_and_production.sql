-- Add unit columns to daily_stock, overall_stock, and daily_production tables
-- Units can be: 'gram', 'kg', 'Litre' or NULL (for items without units)

-- Add unit column to daily_stock table
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'daily_stock' AND column_name = 'unit'
  ) THEN
    ALTER TABLE daily_stock 
    ADD COLUMN unit VARCHAR(20) CHECK (unit IN ('gram', 'kg', 'Litre') OR unit IS NULL);
    
    COMMENT ON COLUMN daily_stock.unit IS 'Unit of measurement: gram, kg, or Litre';
  END IF;
END $$;

-- Add unit column to overall_stock table
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'overall_stock' AND column_name = 'unit'
  ) THEN
    ALTER TABLE overall_stock 
    ADD COLUMN unit VARCHAR(20) CHECK (unit IN ('gram', 'kg', 'Litre') OR unit IS NULL);
    
    COMMENT ON COLUMN overall_stock.unit IS 'Unit of measurement: gram, kg, or Litre';
  END IF;
END $$;

-- Add unit column to daily_production table
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'daily_production' AND column_name = 'unit'
  ) THEN
    ALTER TABLE daily_production 
    ADD COLUMN unit VARCHAR(20) CHECK (unit IN ('gram', 'kg', 'Litre') OR unit IS NULL);
    
    COMMENT ON COLUMN daily_production.unit IS 'Unit of measurement: gram, kg, or Litre';
  END IF;
END $$;

