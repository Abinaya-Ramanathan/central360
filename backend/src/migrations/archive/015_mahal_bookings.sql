-- Create mahal_bookings table
CREATE TABLE IF NOT EXISTS mahal_bookings (
  id SERIAL PRIMARY KEY,
  sector_code VARCHAR(50) NOT NULL REFERENCES sectors(code) ON DELETE CASCADE,
  mahal_detail VARCHAR(255) NOT NULL,
  event_date DATE NOT NULL,
  event_timing VARCHAR(50),
  event_name VARCHAR(255),
  client_name VARCHAR(255) NOT NULL,
  client_phone1 VARCHAR(50),
  client_phone2 VARCHAR(50),
  client_address TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_mahal_bookings_sector ON mahal_bookings(sector_code);
CREATE INDEX IF NOT EXISTS idx_mahal_bookings_event_date ON mahal_bookings(event_date);
CREATE INDEX IF NOT EXISTS idx_mahal_bookings_mahal_detail ON mahal_bookings(mahal_detail);

