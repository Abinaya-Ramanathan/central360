-- Create catering_details table
CREATE TABLE IF NOT EXISTS catering_details (
  booking_id VARCHAR(255) PRIMARY KEY REFERENCES mahal_bookings(booking_id) ON DELETE CASCADE,
  morning_food_menu TEXT,
  afternoon_food_menu TEXT,
  evening_food_menu TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_catering_details_booking_id ON catering_details(booking_id);

