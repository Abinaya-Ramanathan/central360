-- Update any expenses with null sector_code to a default or delete them
-- First, let's see what we have
-- SELECT id, item_details, amount, expense_date, sector_code FROM daily_expenses WHERE sector_code IS NULL;

-- Option 1: Delete expenses with null sector_code (uncomment to use)
-- DELETE FROM daily_expenses WHERE sector_code IS NULL;

-- Option 2: Set a default sector for null values (uncomment and modify to use)
-- UPDATE daily_expenses 
-- SET sector_code = 'SSBM'  -- Change to your preferred default sector code
-- WHERE sector_code IS NULL;

-- Note: Run this query manually in pgAdmin to see which records have null sector_code
-- Then decide whether to delete them or assign them to a sector

