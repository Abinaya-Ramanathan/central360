-- Add parent_sector_code to sectors so sub-sectors (e.g. under Sri Suryaas Cafe) are stored and returned.
-- When set, the sector appears under the parent's page instead of on the home page.
ALTER TABLE sectors
  ADD COLUMN IF NOT EXISTS parent_sector_code VARCHAR(50) REFERENCES sectors(code) ON DELETE SET NULL;

COMMENT ON COLUMN sectors.parent_sector_code IS 'When set, this sector is a sub-sector of the given parent and appears under that parent in the app.';
