-- Migration 036: Add bulk_advance, bulk_advance_taken, bulk_advance_paid columns to attendance table

DO $$
BEGIN
  -- Add bulk_advance_taken column
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'attendance' AND column_name = 'bulk_advance_taken'
  ) THEN
    ALTER TABLE attendance ADD COLUMN bulk_advance_taken DECIMAL(10, 2) DEFAULT 0;
  END IF;

  -- Add bulk_advance_paid column
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'attendance' AND column_name = 'bulk_advance_paid'
  ) THEN
    ALTER TABLE attendance ADD COLUMN bulk_advance_paid DECIMAL(10, 2) DEFAULT 0;
  END IF;

  -- Add bulk_advance column
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'attendance' AND column_name = 'bulk_advance'
  ) THEN
    ALTER TABLE attendance ADD COLUMN bulk_advance DECIMAL(10, 2) DEFAULT 0;
  END IF;
END $$;

