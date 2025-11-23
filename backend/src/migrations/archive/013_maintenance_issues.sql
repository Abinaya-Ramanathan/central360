-- Create maintenance_issues table
CREATE TABLE IF NOT EXISTS maintenance_issues (
  id SERIAL PRIMARY KEY,
  issue_description TEXT,
  date_created DATE,
  image_url TEXT,
  status VARCHAR(20) DEFAULT 'Not resolved' CHECK (status IN ('Resolved', 'Not resolved')),
  date_resolved DATE,
  sector_code VARCHAR(50) NOT NULL REFERENCES sectors(code) ON DELETE CASCADE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_maintenance_issues_sector ON maintenance_issues(sector_code);
CREATE INDEX IF NOT EXISTS idx_maintenance_issues_date_created ON maintenance_issues(date_created);
CREATE INDEX IF NOT EXISTS idx_maintenance_issues_status ON maintenance_issues(status);

