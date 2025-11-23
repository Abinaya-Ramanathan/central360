-- Add contact2 column to employees table
ALTER TABLE employees
ADD COLUMN IF NOT EXISTS contact2 VARCHAR(50);

