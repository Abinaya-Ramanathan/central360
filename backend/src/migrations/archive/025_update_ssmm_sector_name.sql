-- Update SSMM sector name to SSMMC
UPDATE sectors 
SET code = 'SSMMC', 
    name = 'SRI SURYA MAHAL MINI HALL AND CATERING'
WHERE code = 'SSMM';

-- Update any existing mahal_bookings that reference SSMM
UPDATE mahal_bookings 
SET sector_code = 'SSMMC'
WHERE sector_code = 'SSMM';

