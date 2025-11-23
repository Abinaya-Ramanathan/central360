-- Update mahal_bookings table to add booking_id as primary key and food_service
-- First, drop the existing primary key constraint
ALTER TABLE mahal_bookings DROP CONSTRAINT IF EXISTS mahal_bookings_pkey;

-- Add booking_id column
ALTER TABLE mahal_bookings ADD COLUMN IF NOT EXISTS booking_id VARCHAR(255);

-- Generate booking_id for existing records (if any)
UPDATE mahal_bookings 
SET booking_id = client_name || '_' || event_date::text
WHERE booking_id IS NULL;

-- Make booking_id NOT NULL and add unique constraint
ALTER TABLE mahal_bookings 
  ALTER COLUMN booking_id SET NOT NULL,
  ADD CONSTRAINT mahal_bookings_booking_id_key UNIQUE (booking_id);

-- Add food_service column
ALTER TABLE mahal_bookings 
  ADD COLUMN IF NOT EXISTS food_service VARCHAR(50) CHECK (food_service IN ('Internal', 'External'));

-- Make booking_id the primary key
ALTER TABLE mahal_bookings 
  ADD PRIMARY KEY (booking_id);

-- Keep id column for backward compatibility but remove primary key constraint
-- The id column can remain as a unique identifier but booking_id is now the primary key

-- Add index on booking_id (already indexed as primary key, but explicit for clarity)
CREATE INDEX IF NOT EXISTS idx_mahal_bookings_booking_id ON mahal_bookings(booking_id);

