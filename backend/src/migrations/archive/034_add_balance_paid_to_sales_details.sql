-- Migration 034: Add balance_paid column to sales_details table

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'sales_details' AND column_name = 'balance_paid'
  ) THEN
    ALTER TABLE sales_details ADD COLUMN balance_paid DECIMAL(10, 2) DEFAULT 0;
  END IF;
END $$;

