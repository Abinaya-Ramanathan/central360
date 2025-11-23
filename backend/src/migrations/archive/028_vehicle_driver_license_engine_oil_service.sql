-- Create vehicle_licenses table
CREATE TABLE IF NOT EXISTS vehicle_licenses (
  id SERIAL PRIMARY KEY,
  sector_code VARCHAR(50) REFERENCES sectors(code) ON DELETE CASCADE,
  name VARCHAR(255) NOT NULL,
  model VARCHAR(255) NOT NULL,
  registration_number VARCHAR(255) NOT NULL,
  permit_date DATE,
  insurance_date DATE,
  fitness_date DATE,
  pollution_date DATE,
  tax_date DATE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_vehicle_licenses_sector ON vehicle_licenses(sector_code);
CREATE INDEX IF NOT EXISTS idx_vehicle_licenses_registration ON vehicle_licenses(registration_number);

-- Create driver_licenses table
CREATE TABLE IF NOT EXISTS driver_licenses (
  id SERIAL PRIMARY KEY,
  sector_code VARCHAR(50) REFERENCES sectors(code) ON DELETE CASCADE,
  driver_name VARCHAR(255) NOT NULL,
  license_number VARCHAR(255) NOT NULL,
  expiry_date DATE NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_driver_licenses_sector ON driver_licenses(sector_code);
CREATE INDEX IF NOT EXISTS idx_driver_licenses_number ON driver_licenses(license_number);
CREATE INDEX IF NOT EXISTS idx_driver_licenses_expiry ON driver_licenses(expiry_date);

-- Create engine_oil_services table
CREATE TABLE IF NOT EXISTS engine_oil_services (
  id SERIAL PRIMARY KEY,
  sector_code VARCHAR(50) REFERENCES sectors(code) ON DELETE CASCADE,
  vehicle_name VARCHAR(255) NOT NULL,
  model VARCHAR(255) NOT NULL,
  service_part_name VARCHAR(255) NOT NULL,
  service_date DATE NOT NULL,
  service_in_kms INTEGER,
  service_in_hrs INTEGER,
  next_service_date DATE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_engine_oil_services_sector ON engine_oil_services(sector_code);
CREATE INDEX IF NOT EXISTS idx_engine_oil_services_date ON engine_oil_services(service_date);
CREATE INDEX IF NOT EXISTS idx_engine_oil_services_vehicle ON engine_oil_services(vehicle_name);

