-- Migration 048: Add ot_hours column to attendance table

DO $$
BEGIN
  -- Add ot_hours column
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'attendance' AND column_name = 'ot_hours'
  ) THEN
    ALTER TABLE attendance ADD COLUMN ot_hours DECIMAL(10, 2) DEFAULT 0;
  END IF;
END $$;

