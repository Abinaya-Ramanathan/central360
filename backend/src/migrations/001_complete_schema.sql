-- ============================================
-- Central360 Complete Database Schema
-- ============================================
-- This file contains all tables in their final state
-- Consolidates migrations 001-031 into a single schema
-- Last updated: Includes all features through migration 031
-- ============================================

-- ============================================
-- 1. SECTORS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS sectors (
  code VARCHAR(50) PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- 2. EMPLOYEES TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS employees (
  id SERIAL PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  contact VARCHAR(50) NOT NULL,
  contact2 VARCHAR(50), -- Added in migration 012
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

-- ============================================
-- 3. ATTENDANCE TABLE
-- ============================================
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

-- ============================================
-- 4. SALARY EXPENSES TABLE
-- ============================================
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
  advance_deducted INTEGER DEFAULT 0, -- Added in migration 003
  selected_dates TEXT, -- JSON array of selected dates
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- 5. DAILY PRODUCTION TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS daily_production (
  id SERIAL PRIMARY KEY,
  product_name VARCHAR(255) NOT NULL,
  morning_production INTEGER NOT NULL DEFAULT 0,
  afternoon_production INTEGER NOT NULL DEFAULT 0,
  evening_production INTEGER NOT NULL DEFAULT 0,
  production_date DATE NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- 6. PRODUCTS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS products (
  id SERIAL PRIMARY KEY,
  product_name VARCHAR(255) NOT NULL,
  sector_code VARCHAR(50) NOT NULL REFERENCES sectors(code) ON DELETE CASCADE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(product_name, sector_code)
);

-- ============================================
-- 7. DAILY EXPENSES TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS daily_expenses (
  id SERIAL PRIMARY KEY,
  item_details VARCHAR(255) NOT NULL,
  amount DECIMAL(10, 2) NOT NULL,
  reason_for_purchase TEXT,
  expense_date DATE NOT NULL,
  sector_code VARCHAR(50) NOT NULL REFERENCES sectors(code) ON DELETE RESTRICT, -- Added in migration 010
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- 8. MAINTENANCE ISSUES TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS maintenance_issues (
  id SERIAL PRIMARY KEY,
  sector_code VARCHAR(50) NOT NULL REFERENCES sectors(code) ON DELETE RESTRICT,
  issue_description TEXT,
  date_created DATE,
  status VARCHAR(20) DEFAULT 'Not resolved' CHECK (status IN ('Resolved', 'Not resolved')),
  date_resolved DATE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- 9. MAHAL BOOKINGS TABLE (Event Details)
-- ============================================
CREATE TABLE IF NOT EXISTS mahal_bookings (
  booking_id VARCHAR(255) PRIMARY KEY, -- Changed to primary key in migration 016
  sector_code VARCHAR(50) NOT NULL REFERENCES sectors(code) ON DELETE RESTRICT,
  mahal_detail VARCHAR(255) NOT NULL,
  event_date DATE NOT NULL,
  event_timing VARCHAR(255),
  event_name VARCHAR(255),
  client_name VARCHAR(255) NOT NULL,
  client_phone1 VARCHAR(50),
  client_phone2 VARCHAR(50),
  client_address TEXT,
  food_service VARCHAR(50), -- Added in migration 016
  advance_received DECIMAL(10, 2) DEFAULT 0, -- Added in migration 022
  quoted_amount DECIMAL(10, 2) DEFAULT 0, -- Added in migration 022
  amount_received DECIMAL(10, 2) DEFAULT 0, -- Added in migration 022
  order_status VARCHAR(20) DEFAULT 'open' CHECK (order_status IN ('open', 'closed')), -- Added in migration 022
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- 10. CATERING DETAILS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS catering_details (
  booking_id VARCHAR(255) PRIMARY KEY REFERENCES mahal_bookings(booking_id) ON DELETE CASCADE,
  delivery_location TEXT, -- Added in migration 030
  morning_food_menu TEXT,
  morning_food_count INTEGER DEFAULT 0, -- Added in migration 023
  afternoon_food_menu TEXT,
  afternoon_food_count INTEGER DEFAULT 0, -- Added in migration 023
  evening_food_menu TEXT,
  evening_food_count INTEGER DEFAULT 0, -- Added in migration 023
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- 11. EXPENSE DETAILS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS expense_details (
  booking_id VARCHAR(255) PRIMARY KEY REFERENCES mahal_bookings(booking_id) ON DELETE CASCADE,
  master_salary DECIMAL(10, 2) DEFAULT 0,
  cooking_helper_salary DECIMAL(10, 2) DEFAULT 0,
  external_catering_salary DECIMAL(10, 2) DEFAULT 0,
  current_bill DECIMAL(10, 2) DEFAULT 0, -- Added in migration 020
  cleaning_bill DECIMAL(10, 2) DEFAULT 0, -- Added in migration 020
  grocery_bill DECIMAL(10, 2) DEFAULT 0, -- Added in migration 020
  vegetable_bill DECIMAL(10, 2) DEFAULT 0, -- Added in migration 020
  cylinder_amount DECIMAL(10, 2) DEFAULT 0, -- Added in migration 020 (cylinder_qty removed in 021)
  morning_food_expense DECIMAL(10, 2) DEFAULT 0, -- Added in migration 020
  afternoon_food_expense DECIMAL(10, 2) DEFAULT 0, -- Added in migration 020
  evening_food_expense DECIMAL(10, 2) DEFAULT 0, -- Added in migration 020
  vehicle_expense DECIMAL(10, 2) DEFAULT 0, -- Added in migration 024
  packing_items_charge DECIMAL(10, 2) DEFAULT 0, -- Added in migration 029
  details TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- 12. CREDIT DETAILS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS credit_details (
  id SERIAL PRIMARY KEY,
  sector_code VARCHAR(50) NOT NULL REFERENCES sectors(code) ON DELETE RESTRICT,
  name VARCHAR(255) NOT NULL,
  phone_number VARCHAR(50),
  address TEXT,
  purchase_details TEXT,
  credit_amount DECIMAL(10, 2) NOT NULL DEFAULT 0,
  amount_settled DECIMAL(10, 2) DEFAULT 0,
  credit_date DATE NOT NULL, -- Added in migration 026
  full_settlement_date DATE, -- Added in migration 027
  comments TEXT, -- Added in migration 031
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- INDEXES FOR PERFORMANCE
-- ============================================
-- Employees indexes
CREATE INDEX IF NOT EXISTS idx_employees_sector ON employees(sector);

-- Attendance indexes
CREATE INDEX IF NOT EXISTS idx_attendance_date ON attendance(date);
CREATE INDEX IF NOT EXISTS idx_attendance_sector ON attendance(sector);
CREATE INDEX IF NOT EXISTS idx_attendance_employee_date ON attendance(employee_id, date);

-- Salary expenses indexes
CREATE INDEX IF NOT EXISTS idx_salary_expenses_employee ON salary_expenses(employee_id);
CREATE INDEX IF NOT EXISTS idx_salary_expenses_sector ON salary_expenses(sector);
CREATE INDEX IF NOT EXISTS idx_salary_expenses_week ON salary_expenses(week_start_date, week_end_date);
CREATE INDEX IF NOT EXISTS idx_salary_expenses_employee_month ON salary_expenses(employee_id, week_start_date, week_end_date);

-- Daily production indexes
CREATE INDEX IF NOT EXISTS idx_daily_production_date ON daily_production(production_date);
CREATE INDEX IF NOT EXISTS idx_daily_production_product_date ON daily_production(product_name, production_date);

-- Daily expenses indexes
CREATE INDEX IF NOT EXISTS idx_daily_expenses_date ON daily_expenses(expense_date);
CREATE INDEX IF NOT EXISTS idx_daily_expenses_sector ON daily_expenses(sector_code);

-- Maintenance issues indexes
CREATE INDEX IF NOT EXISTS idx_maintenance_issues_sector ON maintenance_issues(sector_code);
CREATE INDEX IF NOT EXISTS idx_maintenance_issues_date ON maintenance_issues(date_created);

-- Mahal bookings indexes
CREATE INDEX IF NOT EXISTS idx_mahal_bookings_sector ON mahal_bookings(sector_code);
CREATE INDEX IF NOT EXISTS idx_mahal_bookings_date ON mahal_bookings(event_date);

-- Credit details indexes
CREATE INDEX IF NOT EXISTS idx_credit_details_sector ON credit_details(sector_code);
CREATE INDEX IF NOT EXISTS idx_credit_details_date ON credit_details(credit_date);

-- ============================================
-- 13. VEHICLE LICENSES TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS vehicle_licenses (
  id SERIAL PRIMARY KEY,
  sector_code VARCHAR(50) REFERENCES sectors(code) ON DELETE CASCADE,
  name VARCHAR(255) NOT NULL,
  model VARCHAR(255) NOT NULL,
  registration_number VARCHAR(255) NOT NULL,
  permit_date DATE,
  insurance_date DATE,
  fitness_date DATE,
  pollution_date DATE,
  tax_date DATE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_vehicle_licenses_sector ON vehicle_licenses(sector_code);
CREATE INDEX IF NOT EXISTS idx_vehicle_licenses_registration ON vehicle_licenses(registration_number);
CREATE INDEX IF NOT EXISTS idx_vehicle_licenses_permit_date ON vehicle_licenses(permit_date);
CREATE INDEX IF NOT EXISTS idx_vehicle_licenses_insurance_date ON vehicle_licenses(insurance_date);
CREATE INDEX IF NOT EXISTS idx_vehicle_licenses_fitness_date ON vehicle_licenses(fitness_date);
CREATE INDEX IF NOT EXISTS idx_vehicle_licenses_pollution_date ON vehicle_licenses(pollution_date);
CREATE INDEX IF NOT EXISTS idx_vehicle_licenses_tax_date ON vehicle_licenses(tax_date);

-- ============================================
-- 14. DRIVER LICENSES TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS driver_licenses (
  id SERIAL PRIMARY KEY,
  sector_code VARCHAR(50) REFERENCES sectors(code) ON DELETE CASCADE,
  driver_name VARCHAR(255) NOT NULL,
  license_number VARCHAR(255) NOT NULL,
  expiry_date DATE NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_driver_licenses_sector ON driver_licenses(sector_code);
CREATE INDEX IF NOT EXISTS idx_driver_licenses_number ON driver_licenses(license_number);
CREATE INDEX IF NOT EXISTS idx_driver_licenses_expiry ON driver_licenses(expiry_date);

-- ============================================
-- 15. ENGINE OIL SERVICES TABLE (Vehicle Services)
-- ============================================
CREATE TABLE IF NOT EXISTS engine_oil_services (
  id SERIAL PRIMARY KEY,
  sector_code VARCHAR(50) REFERENCES sectors(code) ON DELETE CASCADE,
  vehicle_name VARCHAR(255) NOT NULL,
  model VARCHAR(255) NOT NULL,
  service_part_name VARCHAR(255) NOT NULL,
  service_date DATE NOT NULL,
  service_in_kms INTEGER,
  service_in_hrs INTEGER,
  next_service_date DATE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_engine_oil_services_sector ON engine_oil_services(sector_code);
CREATE INDEX IF NOT EXISTS idx_engine_oil_services_date ON engine_oil_services(service_date);
CREATE INDEX IF NOT EXISTS idx_engine_oil_services_next_date ON engine_oil_services(next_service_date);
CREATE INDEX IF NOT EXISTS idx_engine_oil_services_vehicle ON engine_oil_services(vehicle_name);

