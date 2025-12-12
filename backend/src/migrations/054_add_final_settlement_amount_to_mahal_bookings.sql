-- ============================================
-- Add final_settlement_amount column to mahal_bookings
-- Migration 054: Add final_settlement_amount field for event details
-- ============================================

ALTER TABLE mahal_bookings 
ADD COLUMN IF NOT EXISTS final_settlement_amount DECIMAL(10, 2);

-- Add comment to column
COMMENT ON COLUMN mahal_bookings.final_settlement_amount IS 'Final settlement amount for the event';

-- Analyze table to update statistics
ANALYZE mahal_bookings;

