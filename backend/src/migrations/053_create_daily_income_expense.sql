-- ============================================
-- Daily Income and Expense Table
-- Migration 053: Create table for daily income/expense tracking
-- ============================================

CREATE TABLE IF NOT EXISTS daily_income_expense (
  id SERIAL PRIMARY KEY,
  sector_code VARCHAR(50) NOT NULL REFERENCES sectors(code) ON DELETE RESTRICT,
  item_name VARCHAR(255),
  quantity VARCHAR(255),
  income_amount DECIMAL(10, 2) DEFAULT 0,
  expense_amount DECIMAL(10, 2) DEFAULT 0,
  entry_date DATE NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_daily_income_expense_sector ON daily_income_expense(sector_code);
CREATE INDEX IF NOT EXISTS idx_daily_income_expense_date ON daily_income_expense(entry_date);
CREATE INDEX IF NOT EXISTS idx_daily_income_expense_sector_date ON daily_income_expense(sector_code, entry_date);

-- Analyze table to update statistics
ANALYZE daily_income_expense;

