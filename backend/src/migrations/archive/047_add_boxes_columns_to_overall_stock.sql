-- Add boxes columns to overall_stock table

DO $$ BEGIN
  -- Add remaining_stock_boxes column
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'overall_stock' AND column_name = 'remaining_stock_boxes'
  ) THEN
    ALTER TABLE overall_stock 
    ADD COLUMN remaining_stock_boxes DECIMAL(10, 2) DEFAULT 0;
    
    COMMENT ON COLUMN overall_stock.remaining_stock_boxes IS 'Remaining stock quantity in boxes';
  END IF;

  -- Add new_stock_boxes column
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'overall_stock' AND column_name = 'new_stock_boxes'
  ) THEN
    ALTER TABLE overall_stock 
    ADD COLUMN new_stock_boxes DECIMAL(10, 2) DEFAULT 0;
    
    COMMENT ON COLUMN overall_stock.new_stock_boxes IS 'New stock quantity in boxes';
  END IF;
END $$;

