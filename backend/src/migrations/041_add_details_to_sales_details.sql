-- Migration 041: Add details column to sales_details table

-- Check if column exists before adding
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'sales_details' AND column_name = 'details'
    ) THEN
        ALTER TABLE sales_details ADD COLUMN details TEXT;
    END IF;
END $$;

