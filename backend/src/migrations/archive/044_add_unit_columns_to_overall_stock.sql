-- Add separate columns for each unit type in overall_stock table
-- This allows storing quantities in gram, kg, and litre simultaneously

DO $$ BEGIN
  -- Add remaining stock columns for each unit
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'overall_stock' AND column_name = 'remaining_stock_gram'
  ) THEN
    ALTER TABLE overall_stock 
    ADD COLUMN remaining_stock_gram DECIMAL(10, 2) DEFAULT 0,
    ADD COLUMN remaining_stock_kg DECIMAL(10, 2) DEFAULT 0,
    ADD COLUMN remaining_stock_litre DECIMAL(10, 2) DEFAULT 0;
    
    COMMENT ON COLUMN overall_stock.remaining_stock_gram IS 'Remaining stock quantity in grams';
    COMMENT ON COLUMN overall_stock.remaining_stock_kg IS 'Remaining stock quantity in kilograms';
    COMMENT ON COLUMN overall_stock.remaining_stock_litre IS 'Remaining stock quantity in litres';
  END IF;

  -- Add new stock columns for each unit
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'overall_stock' AND column_name = 'new_stock_gram'
  ) THEN
    ALTER TABLE overall_stock 
    ADD COLUMN new_stock_gram DECIMAL(10, 2) DEFAULT 0,
    ADD COLUMN new_stock_kg DECIMAL(10, 2) DEFAULT 0,
    ADD COLUMN new_stock_litre DECIMAL(10, 2) DEFAULT 0;
    
    COMMENT ON COLUMN overall_stock.new_stock_gram IS 'New stock quantity in grams';
    COMMENT ON COLUMN overall_stock.new_stock_kg IS 'New stock quantity in kilograms';
    COMMENT ON COLUMN overall_stock.new_stock_litre IS 'New stock quantity in litres';
  END IF;
END $$;

