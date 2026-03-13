-- ============================================
-- Copy stock items from one sector to another
-- ============================================
-- 1. Replace 'SOURCE_CODE' and 'TARGET_CODE' below with your sector codes.
-- 2. Run the INSERT. Only stock_items (item definitions) are copied.
--    daily_stock and overall_stock are NOT copied (they reference item ids).
-- ============================================

-- Preview: items that will be copied
SELECT
  item_name,
  vehicle_type,
  part_number,
  'SOURCE_CODE' AS source_sector,
  'TARGET_CODE' AS target_sector
FROM stock_items
WHERE sector_code = 'SOURCE_CODE'
ORDER BY item_name;

-- Copy: insert into target sector (skips if item_name already exists for target)
INSERT INTO stock_items (item_name, sector_code, vehicle_type, part_number)
SELECT
  item_name,
  'TARGET_CODE' AS sector_code,
  vehicle_type,
  part_number
FROM stock_items
WHERE sector_code = 'SOURCE_CODE'
ON CONFLICT (item_name, sector_code) DO NOTHING;

-- Verify: count in target sector
SELECT sector_code, COUNT(*) AS item_count
FROM stock_items
WHERE sector_code IN ('SOURCE_CODE', 'TARGET_CODE')
GROUP BY sector_code;
