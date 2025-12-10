import { Router } from 'express';
import db from '../db.js';

const router = Router();

// Get daily production records
router.get('/', async (req, res) => {
  try {
    const startTime = Date.now();
    const { month, date } = req.query;
    // Optimized: Only select needed columns
    let query = 'SELECT id, product_name, sector_code, morning_production, afternoon_production, evening_production, unit, production_date FROM daily_production WHERE 1=1';
    const params = [];
    let paramCount = 1;

    if (month) {
      // Filter by month (YYYY-MM format)
      query += ` AND DATE_TRUNC('month', production_date) = $${paramCount++}::date`;
      params.push(month + '-01');
    }
    if (date) {
      // Filter by specific date
      query += ` AND production_date = $${paramCount++}::date`;
      params.push(date);
    }

    query += ' ORDER BY production_date DESC, product_name';
    const { rows } = await db.query(query, params);
    const duration = Date.now() - startTime;
    console.log(`[Performance] Daily production query took ${duration}ms, returned ${rows.length} records`);
    res.json(rows);
  } catch (err) {
    console.error('Error fetching daily production:', err);
    res.status(500).json({ message: 'Error fetching daily production' });
  }
});

// Helper function to parse numeric values (accepts both string and number)
function parseNumeric(value) {
  if (value === null || value === undefined || value === '') {
    return 0;
  }
  if (typeof value === 'number') {
    return parseFloat(value); // Keep as float for decimal support
  }
  if (typeof value === 'string') {
    // Trim whitespace
    const trimmed = value.trim();
    
    // Check if it's a fraction (e.g., "1/2", "3/4")
    if (trimmed.includes('/')) {
      const parts = trimmed.split('/');
      if (parts.length === 2) {
        const numerator = parseFloat(parts[0].trim());
        const denominator = parseFloat(parts[1].trim());
        if (!isNaN(numerator) && !isNaN(denominator) && denominator !== 0) {
          return numerator / denominator;
        }
      }
    }
    
    // Try parsing as regular number (decimal supported)
    const parsed = parseFloat(trimmed);
    return isNaN(parsed) ? 0 : parsed;
  }
  return 0;
}

// Create or update daily production record
router.post('/', async (req, res) => {
  try {
    const {
      id,
      product_name,
      sector_code,
      morning_production,
      afternoon_production,
      evening_production,
      unit,
      production_date,
    } = req.body;

    // Validation
    if (!product_name || !production_date) {
      return res.status(400).json({ message: 'Product name and production date are required' });
    }
    if (!sector_code) {
      return res.status(400).json({ message: 'Sector code is required' });
    }

    // Parse numeric values (accepts both string and number)
    const morningProd = parseNumeric(morning_production);
    const afternoonProd = parseNumeric(afternoon_production);
    const eveningProd = parseNumeric(evening_production);

    let rows;
    
    // If ID is provided, update existing record by ID
    if (id) {
      const result = await db.query(
        `UPDATE daily_production SET
          product_name = $1, sector_code = $2, morning_production = $3, afternoon_production = $4,
          evening_production = $5, unit = $6, production_date = $7, updated_at = CURRENT_TIMESTAMP
        WHERE id = $8
        RETURNING *`,
        [
          product_name,
          sector_code,
          morningProd,
          afternoonProd,
          eveningProd,
          unit || null,
          production_date,
          id,
        ]
      );
      rows = result.rows;
      if (rows.length === 0) {
        return res.status(404).json({ message: 'Daily production record not found' });
      }
    } else {
      // Check if record exists for this product, sector, and date
      const existingResult = await db.query(
        'SELECT id FROM daily_production WHERE product_name = $1 AND sector_code = $2 AND production_date = $3',
        [product_name, sector_code, production_date]
      );
      
      if (existingResult.rows.length > 0) {
        // Update existing record
        const existingId = existingResult.rows[0].id;
        const result = await db.query(
          `UPDATE daily_production SET
            morning_production = $1, afternoon_production = $2,
            evening_production = $3, unit = $4, updated_at = CURRENT_TIMESTAMP
          WHERE id = $5
          RETURNING *`,
          [
            morningProd,
            afternoonProd,
            eveningProd,
            unit || null,
            existingId,
          ]
        );
        rows = result.rows;
      } else {
        // Create new record
        const result = await db.query(
          `INSERT INTO daily_production (
            product_name, sector_code, morning_production, afternoon_production,
            evening_production, unit, production_date
          ) VALUES ($1, $2, $3, $4, $5, $6, $7)
          RETURNING *`,
          [
            product_name,
            sector_code,
            morningProd,
            afternoonProd,
            eveningProd,
            unit || null,
            production_date,
          ]
        );
        rows = result.rows;
      }
    }

    res.status(201).json(rows[0]);
  } catch (err) {
    console.error('Error saving daily production:', err);
    console.error('Error details:', {
      code: err.code,
      message: err.message,
      detail: err.detail,
      body: req.body
    });
    res.status(500).json({ 
      message: 'Error saving daily production',
      error: process.env.NODE_ENV === 'development' ? err.message : undefined
    });
  }
});

// Delete daily production record
router.delete('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    
    const result = await db.query(
      'DELETE FROM daily_production WHERE id = $1 RETURNING *',
      [id]
    );
    
    if (result.rows.length === 0) {
      return res.status(404).json({ message: 'Daily production record not found' });
    }
    
    res.status(200).json({ message: 'Daily production record deleted successfully' });
  } catch (err) {
    console.error('Error deleting daily production:', err);
    res.status(500).json({ 
      message: 'Error deleting daily production',
      error: process.env.NODE_ENV === 'development' ? err.message : undefined
    });
  }
});

export default router;

