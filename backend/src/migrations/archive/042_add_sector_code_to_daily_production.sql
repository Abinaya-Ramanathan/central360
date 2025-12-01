-- Add sector_code column to daily_production table
-- This allows production data to be associated with specific sectors

DO $$ 
DECLARE
  constraint_name TEXT;
BEGIN
  -- Check if sector_code column exists, if not add it
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'daily_production' AND column_name = 'sector_code'
  ) THEN
    ALTER TABLE daily_production 
    ADD COLUMN sector_code VARCHAR(50) REFERENCES sectors(code) ON DELETE CASCADE;
    
    -- Create index for better query performance
    CREATE INDEX IF NOT EXISTS idx_daily_production_sector ON daily_production(sector_code);
    
    -- Update unique constraint to include sector_code
    -- First, drop any existing unique constraints on daily_production
    -- Find and drop any unique constraints on (product_name, production_date)
    FOR constraint_name IN
      SELECT conname FROM pg_constraint 
      WHERE conrelid = 'daily_production'::regclass 
      AND contype = 'u'
      AND array_length(conkey, 1) = 2
    LOOP
      EXECUTE 'ALTER TABLE daily_production DROP CONSTRAINT IF EXISTS ' || constraint_name;
    END LOOP;
    
    -- Add new unique constraint including sector_code
    -- Only add if it doesn't already exist
    IF NOT EXISTS (
      SELECT 1 FROM pg_constraint 
      WHERE conname = 'daily_production_product_sector_date_unique'
    ) THEN
      ALTER TABLE daily_production 
      ADD CONSTRAINT daily_production_product_sector_date_unique 
      UNIQUE(product_name, sector_code, production_date);
    END IF;
    
    COMMENT ON COLUMN daily_production.sector_code IS 'Sector code associated with this production record';
  END IF;
END $$;

