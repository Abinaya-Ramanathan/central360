-- ============================================
-- Add vehicle_type and part_number to stock_items
-- ============================================
ALTER TABLE stock_items 
ADD COLUMN IF NOT EXISTS vehicle_type VARCHAR(255),
ADD COLUMN IF NOT EXISTS part_number VARCHAR(255);

