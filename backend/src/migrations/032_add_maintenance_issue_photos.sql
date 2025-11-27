-- Migration 032: Add maintenance_issue_photos table for multiple photos per issue
-- This allows storing multiple photos for each maintenance issue

CREATE TABLE IF NOT EXISTS maintenance_issue_photos (
  id SERIAL PRIMARY KEY,
  issue_id INTEGER NOT NULL REFERENCES maintenance_issues(id) ON DELETE CASCADE,
  image_url VARCHAR(500) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_maintenance_issue_photos_issue ON maintenance_issue_photos(issue_id);

-- Add image_url column to maintenance_issues for backward compatibility (if not exists)
DO $$ 
BEGIN 
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'maintenance_issues' AND column_name = 'image_url'
  ) THEN
    ALTER TABLE maintenance_issues ADD COLUMN image_url VARCHAR(500);
  END IF;
END $$;

