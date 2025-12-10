-- ============================================
-- Performance Optimization Indexes
-- Migration 051: Add missing indexes for query performance
-- ============================================

-- Add index on employees.name for ORDER BY queries (used in employees list)
CREATE INDEX IF NOT EXISTS idx_employees_name ON employees(name);

-- Add composite index for employees sector + name (common query pattern)
CREATE INDEX IF NOT EXISTS idx_employees_sector_name ON employees(sector, name);

-- Add index on employees.id for faster lookups (though primary key already has one, this ensures it)
-- Primary key already has index, but adding explicit one for clarity
-- CREATE INDEX IF NOT EXISTS idx_employees_id ON employees(id); -- Not needed, PK has index

-- Add index on attendance.employee_id for faster joins (if not already covered)
-- The composite index idx_attendance_employee_date should cover this, but adding explicit one
CREATE INDEX IF NOT EXISTS idx_attendance_employee_id ON attendance(employee_id);

-- Add index on products.sector_code for faster filtering (if not already exists)
-- This should already exist from the unique constraint, but ensuring it's there
CREATE INDEX IF NOT EXISTS idx_products_sector_code ON products(sector_code);

-- Add index on stock_items.sector_code (should already exist, but ensuring)
CREATE INDEX IF NOT EXISTS idx_stock_items_sector_code ON stock_items(sector_code);

-- Additional indexes for other frequently queried tables

-- Daily expenses composite indexes for faster filtering
CREATE INDEX IF NOT EXISTS idx_daily_expenses_sector_date ON daily_expenses(sector_code, expense_date);
CREATE INDEX IF NOT EXISTS idx_daily_expenses_date_sector ON daily_expenses(expense_date, sector_code);

-- Daily production composite indexes for faster filtering
CREATE INDEX IF NOT EXISTS idx_daily_production_sector_date ON daily_production(sector_code, production_date);
CREATE INDEX IF NOT EXISTS idx_daily_production_date_product ON daily_production(production_date, product_name);

-- Credit details composite indexes for faster filtering
CREATE INDEX IF NOT EXISTS idx_credit_details_sector_date ON credit_details(sector_code, credit_date);
CREATE INDEX IF NOT EXISTS idx_credit_details_date_sector ON credit_details(credit_date, sector_code);

-- Salary expenses composite indexes for faster filtering
CREATE INDEX IF NOT EXISTS idx_salary_expenses_employee_week ON salary_expenses(employee_id, week_start_date, week_end_date);
CREATE INDEX IF NOT EXISTS idx_salary_expenses_sector_week ON salary_expenses(sector, week_start_date);

-- Analyze tables to update statistics for query planner
ANALYZE employees;
ANALYZE attendance;
ANALYZE products;
ANALYZE stock_items;
ANALYZE daily_expenses;
ANALYZE daily_production;
ANALYZE credit_details;
ANALYZE salary_expenses;

