-- Create contract_employees table
CREATE TABLE IF NOT EXISTS contract_employees (
  id SERIAL PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  members_count INTEGER NOT NULL,
  reason TEXT,
  salary_per_count DECIMAL(10, 2) NOT NULL,
  total_salary DECIMAL(10, 2) NOT NULL,
  date DATE NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_contract_employees_date ON contract_employees(date);

