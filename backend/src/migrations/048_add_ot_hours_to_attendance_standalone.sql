-- Migration 048: Add ot_hours column to attendance table
-- Run this directly on your production database (Railway)

-- Add ot_hours column if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'attendance' AND column_name = 'ot_hours'
  ) THEN
    ALTER TABLE attendance ADD COLUMN ot_hours DECIMAL(10, 2) DEFAULT 0;
    RAISE NOTICE 'Column ot_hours added successfully to attendance table';
  ELSE
    RAISE NOTICE 'Column ot_hours already exists in attendance table';
  END IF;
END $$;

