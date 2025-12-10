-- ============================================
-- Make sales_details.name field optional
-- Migration 052: Allow NULL values for name field
-- ============================================

-- Alter the name column to allow NULL values
ALTER TABLE sales_details 
ALTER COLUMN name DROP NOT NULL;

-- Update any existing empty strings to NULL for consistency
UPDATE sales_details 
SET name = NULL 
WHERE name = '' OR name IS NULL;

