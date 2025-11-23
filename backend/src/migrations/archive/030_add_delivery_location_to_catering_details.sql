-- Add delivery_location column to catering_details table
ALTER TABLE catering_details 
  ADD COLUMN IF NOT EXISTS delivery_location TEXT;

