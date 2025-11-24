import dotenv from 'dotenv';
dotenv.config(); // Load environment variables before accessing them

import pkg from 'pg';
const { Pool } = pkg;

// Create pool configuration - support both connection string and individual parameters
let poolConfig;

// Priority 1: Use DATABASE_URL (Railway provides this automatically)
if (process.env.DATABASE_URL) {
  const connectionString = process.env.DATABASE_URL;
  
  // Check if password might need URL encoding
  if (connectionString.includes('@') && !connectionString.match(/:\/\/[^:]+:[^@]+@/)) {
    console.warn('WARNING: DATABASE_URL format might be incorrect.');
    console.warn('Expected format: postgres://username:password@host:port/database');
    console.warn('If your password contains special characters, use individual DB_* parameters instead.');
  }

  poolConfig = {
    connectionString: connectionString,
    connectionTimeoutMillis: 5000,
    idleTimeoutMillis: 30000,
  };
  console.log('Using DATABASE_URL connection string');
}
// Option 2: Use individual parameters (fallback if DATABASE_URL not available)
else if (process.env.DB_HOST && process.env.DB_USER && process.env.DB_PASSWORD && process.env.DB_NAME) {
  poolConfig = {
    host: process.env.DB_HOST,
    port: parseInt(process.env.DB_PORT || '5432'),
    database: process.env.DB_NAME,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    connectionTimeoutMillis: 5000,
    idleTimeoutMillis: 30000,
  };
  console.log('Using individual database connection parameters');
}
else {
  console.error('ERROR: Database configuration is missing!');
  console.error('\nPlease set either:');
  console.error('1. DATABASE_URL=postgres://user:password@host:port/database');
  console.error('   (URL-encode special characters in password: @ -> %40, : -> %3A, etc.)');
  console.error('\nOR use individual parameters:');
  console.error('2. DB_HOST=localhost');
  console.error('   DB_PORT=5432');
  console.error('   DB_USER=your_username');
  console.error('   DB_PASSWORD=your_password');
  console.error('   DB_NAME=central360');
  console.error('\n(Option 2 is recommended if your password contains special characters)');
  process.exit(1);
}

// Create pool with better error handling
let pool;
try {
  pool = new Pool(poolConfig);

  // Test the connection
  pool.on('error', (err) => {
    console.error('Unexpected error on idle client', err);
  });

  // Test connection on startup
  pool.query('SELECT NOW()', (err, res) => {
    if (err) {
      console.error('Database connection test failed:', err.message);
      if (err.message.includes('password must be a string')) {
        console.error('\n=== PASSWORD ERROR TROUBLESHOOTING ===');
        console.error('The database password is not being parsed correctly.');
        console.error('\nSOLUTION: Use individual DB_* parameters instead of DATABASE_URL');
        console.error('In your .env file, replace:');
        console.error('  DATABASE_URL=postgres://user:pass@host/db');
        console.error('With:');
        console.error('  DB_HOST=localhost');
        console.error('  DB_PORT=5432');
        console.error('  DB_USER=your_username');
        console.error('  DB_PASSWORD=your_password');
        console.error('  DB_NAME=central360');
        console.error('\nThis avoids URL encoding issues with special characters.');
      }
    } else {
      console.log('✓ Database connection successful');
    }
  });

} catch (err) {
  console.error('Failed to create database pool:', err);
  process.exit(1);
}

export default {
  query: (text, params) => pool.query(text, params),
  pool,
};


