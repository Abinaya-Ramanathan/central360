-- Create daily_expenses table
CREATE TABLE IF NOT EXISTS daily_expenses (
  id SERIAL PRIMARY KEY,
  item_details VARCHAR(255) NOT NULL,
  amount DECIMAL(10, 2) NOT NULL,
  reason_for_purchase TEXT,
  expense_date DATE NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_daily_expenses_date ON daily_expenses(expense_date);

