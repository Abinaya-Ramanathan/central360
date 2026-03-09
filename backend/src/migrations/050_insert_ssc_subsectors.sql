-- Insert Sri Suryaas Cafe (SSC) sub-sectors so they exist in DB and sector checks pass
-- when adding stock, products, rent vehicles, mining activities, etc.
-- Safe to run multiple times: ON CONFLICT DO NOTHING.

-- Ensure parent_sector_code column exists (for fresh installs that may not have run 049)
ALTER TABLE sectors
  ADD COLUMN IF NOT EXISTS parent_sector_code VARCHAR(50) REFERENCES sectors(code) ON DELETE SET NULL;

INSERT INTO sectors (code, name, parent_sector_code) VALUES
  ('SSCT', 'SRI SURYAAS CAFE THANTHONDRIMALAI', 'SSC'),
  ('CS', 'CANTEEN STORE', 'SSC'),
  ('SSCM', 'SRI SURYAAS CAFE MAIN BRANCH', 'SSC')
ON CONFLICT (code) DO UPDATE SET
  name = EXCLUDED.name,
  parent_sector_code = COALESCE(EXCLUDED.parent_sector_code, sectors.parent_sector_code);
