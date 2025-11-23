-- Create sectors table
CREATE TABLE IF NOT EXISTS sectors (
  code VARCHAR(50) PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create employees table
CREATE TABLE IF NOT EXISTS employees (
  id SERIAL PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  contact VARCHAR(50) NOT NULL,
  address TEXT,
  bank_details TEXT,
  sector VARCHAR(50) NOT NULL REFERENCES sectors(code) ON DELETE RESTRICT,
  role VARCHAR(255),
  daily_salary DECIMAL(10, 2) DEFAULT 0,
  weekly_salary DECIMAL(10, 2) DEFAULT 0,
  monthly_salary DECIMAL(10, 2) DEFAULT 0,
  joining_date DATE,
  joining_year INTEGER,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create attendance table
CREATE TABLE IF NOT EXISTS attendance (
  id SERIAL PRIMARY KEY,
  employee_id INTEGER NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
  employee_name VARCHAR(255) NOT NULL,
  sector VARCHAR(50) NOT NULL,
  date DATE NOT NULL,
  status VARCHAR(20) NOT NULL CHECK (status IN ('present', 'absent', 'halfday')),
  outstanding_advance DECIMAL(10, 2) DEFAULT 0,
  advance_taken DECIMAL(10, 2) DEFAULT 0,
  advance_paid DECIMAL(10, 2) DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(employee_id, date)
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_employees_sector ON employees(sector);
CREATE INDEX IF NOT EXISTS idx_attendance_date ON attendance(date);
CREATE INDEX IF NOT EXISTS idx_attendance_sector ON attendance(sector);
CREATE INDEX IF NOT EXISTS idx_attendance_employee_date ON attendance(employee_id, date);

