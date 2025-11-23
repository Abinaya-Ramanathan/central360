-- Add comments column to credit_details table
ALTER TABLE credit_details ADD COLUMN IF NOT EXISTS comments TEXT;

