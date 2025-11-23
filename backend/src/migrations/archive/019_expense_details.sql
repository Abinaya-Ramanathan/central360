-- Create expense_details table
CREATE TABLE IF NOT EXISTS expense_details (
  booking_id VARCHAR(255) PRIMARY KEY REFERENCES mahal_bookings(booking_id) ON DELETE CASCADE,
  master_salary DECIMAL(10, 2) DEFAULT 0,
  cooking_helper_salary DECIMAL(10, 2) DEFAULT 0,
  external_catering_salary DECIMAL(10, 2) DEFAULT 0,
  others_salary DECIMAL(10, 2) DEFAULT 0,
  details TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_expense_details_booking_id ON expense_details(booking_id);

