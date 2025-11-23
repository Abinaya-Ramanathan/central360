-- Create salary_expenses table
CREATE TABLE IF NOT EXISTS salary_expenses (
  id SERIAL PRIMARY KEY,
  employee_id INTEGER NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
  employee_name VARCHAR(255) NOT NULL,
  sector VARCHAR(50) NOT NULL,
  week_start_date DATE NOT NULL,
  week_end_date DATE NOT NULL,
  outstanding_advance DECIMAL(10, 2) DEFAULT 0,
  days_present INTEGER DEFAULT 0,
  estimated_salary DECIMAL(10, 2) DEFAULT 0,
  salary_issued DECIMAL(10, 2) DEFAULT 0,
  salary_issued_date DATE,
  selected_dates TEXT, -- JSON array of selected dates
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(employee_id, week_start_date, week_end_date)
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_salary_expenses_employee ON salary_expenses(employee_id);
CREATE INDEX IF NOT EXISTS idx_salary_expenses_sector ON salary_expenses(sector);
CREATE INDEX IF NOT EXISTS idx_salary_expenses_week ON salary_expenses(week_start_date, week_end_date);

