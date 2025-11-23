-- Add new fields to mahal_bookings table
ALTER TABLE mahal_bookings 
  ADD COLUMN IF NOT EXISTS advance_received DECIMAL(10, 2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS quoted_amount DECIMAL(10, 2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS amount_received DECIMAL(10, 2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS order_status VARCHAR(50) DEFAULT 'open' CHECK (order_status IN ('open', 'closed'));

CREATE INDEX IF NOT EXISTS idx_mahal_bookings_order_status ON mahal_bookings(order_status);

