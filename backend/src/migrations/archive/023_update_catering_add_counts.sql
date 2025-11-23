-- Add count columns to catering_details table
ALTER TABLE catering_details 
  ADD COLUMN IF NOT EXISTS morning_food_count INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS afternoon_food_count INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS evening_food_count INTEGER DEFAULT 0;

