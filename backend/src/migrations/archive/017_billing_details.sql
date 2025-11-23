-- Create billing_details table
CREATE TABLE IF NOT EXISTS billing_details (
  booking_id VARCHAR(255) PRIMARY KEY REFERENCES mahal_bookings(booking_id) ON DELETE CASCADE,
  current_charge DECIMAL(10, 2) DEFAULT 0,
  cleaning_charge DECIMAL(10, 2) DEFAULT 0,
  vessel_charge DECIMAL(10, 2) DEFAULT 0,
  function_hall_charge DECIMAL(10, 2) DEFAULT 0,
  dining_hall_charge DECIMAL(10, 2) DEFAULT 0,
  grocery_charge DECIMAL(10, 2) DEFAULT 0,
  vegetable_charge DECIMAL(10, 2) DEFAULT 0,
  morning_food DECIMAL(10, 2) DEFAULT 0,
  afternoon_food DECIMAL(10, 2) DEFAULT 0,
  night_food DECIMAL(10, 2) DEFAULT 0,
  cylinder_quantity INTEGER DEFAULT 0,
  cylinder_amount DECIMAL(10, 2) DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_billing_details_booking_id ON billing_details(booking_id);

