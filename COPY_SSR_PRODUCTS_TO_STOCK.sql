-- ============================================
-- Copy SSR Products to Stock Items
-- ============================================
-- This query copies all products from the products table
-- where sector_code = 'SSR' to the stock_items table
-- ============================================

-- Step 1: View SSR products before copying
SELECT 
  id,
  product_name,
  sector_code,
  created_at
FROM products
WHERE sector_code = 'SSR'
ORDER BY product_name;

-- Step 2: Count how many will be copied
SELECT COUNT(*) as total_ssr_products
FROM products
WHERE sector_code = 'SSR';

-- Step 3: Copy SSR products to stock_items
-- This uses INSERT ... ON CONFLICT to avoid duplicates
INSERT INTO stock_items (item_name, sector_code, vehicle_type, part_number, created_at, updated_at)
SELECT 
  product_name as item_name,
  sector_code,
  NULL as vehicle_type,  -- Will be NULL, can update later if needed
  NULL as part_number,   -- Will be NULL, can update later if needed
  created_at,
  CURRENT_TIMESTAMP as updated_at
FROM products
WHERE sector_code = 'SSR'
ON CONFLICT (item_name, sector_code) DO NOTHING;  -- Skip if already exists

-- Step 4: Verify the copy
SELECT 
  si.id,
  si.item_name,
  si.sector_code,
  si.vehicle_type,
  si.part_number,
  si.created_at
FROM stock_items si
WHERE si.sector_code = 'SSR'
ORDER BY si.item_name;

-- Step 5: Count copied items
SELECT COUNT(*) as total_ssr_stock_items
FROM stock_items
WHERE sector_code = 'SSR';

-- ============================================
-- Alternative: If you want to see what will be copied first
-- ============================================
-- Run this to preview what will be inserted:
SELECT 
  product_name as item_name,
  sector_code,
  'Will be NULL' as vehicle_type,
  'Will be NULL' as part_number
FROM products
WHERE sector_code = 'SSR'
ORDER BY product_name;

-- ============================================
-- If you want to update existing items instead of skipping
-- ============================================
-- Uncomment and use this instead of Step 3:
/*
INSERT INTO stock_items (item_name, sector_code, vehicle_type, part_number, created_at, updated_at)
SELECT 
  product_name as item_name,
  sector_code,
  NULL as vehicle_type,
  NULL as part_number,
  created_at,
  CURRENT_TIMESTAMP as updated_at
FROM products
WHERE sector_code = 'SSR'
ON CONFLICT (item_name, sector_code) 
DO UPDATE SET
  updated_at = CURRENT_TIMESTAMP;
*/

