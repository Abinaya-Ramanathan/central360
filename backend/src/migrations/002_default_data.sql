-- ============================================
-- Central360 Default Data
-- ============================================
-- This file contains all default data inserts
-- Consolidates default data from multiple migrations
-- ============================================

-- ============================================
-- DEFAULT SECTORS
-- ============================================
-- Insert default sectors (from migration 006)
-- Update names to all caps (from migration 007)
-- Add SSMMC sector (from migrations 014 and 025)
INSERT INTO sectors (code, name) VALUES
  ('SSBM', 'SRI SURYA BLUE METALS'),
  ('SSC', 'SRI SURYAA''S CAFE'),
  ('SSBP', 'SRI SURYA BHARATH PERTROLEUM'),
  ('SSR', 'SRI SURYA RICEMILL'),
  ('SSACF', 'SRI SURYA AGRO AND CATTLE FARM'),
  ('SSMMC', 'SRI SURYA MAHAL MINI HALL AND CATERING')
ON CONFLICT (code) DO UPDATE SET
  name = EXCLUDED.name;

-- ============================================
-- DEFAULT PRODUCTS FOR SSBM SECTOR
-- ============================================
INSERT INTO products (product_name, sector_code) VALUES
  ('Sholling', 'SSBM'),
  ('Kuli', 'SSBM'),
  ('Gravel', 'SSBM')
ON CONFLICT (product_name, sector_code) DO NOTHING;

-- ============================================
-- DEFAULT PRODUCTS FOR SSACF SECTOR
-- ============================================
INSERT INTO products (product_name, sector_code) VALUES
  ('Milk', 'SSACF'),
  ('Feeds -> Thavudu', 'SSACF'),
  ('Feeds -> Karuka', 'SSACF'),
  ('Feeds -> Punnaku', 'SSACF'),
  ('Feeds -> Fodder Thattai', 'SSACF')
ON CONFLICT (product_name, sector_code) DO NOTHING;

