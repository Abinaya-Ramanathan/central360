-- Migration 035: Add balance_paid_date column to sales_details table

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'sales_details' AND column_name = 'balance_paid_date'
  ) THEN
    ALTER TABLE sales_details ADD COLUMN balance_paid_date DATE;
  END IF;
END $$;

