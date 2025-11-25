import { Router } from 'express';
import db from '../db.js';

const router = Router();

// Get daily production records
router.get('/', async (req, res) => {
  try {
    const { month, date } = req.query;
    let query = 'SELECT * FROM daily_production WHERE 1=1';
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
    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Error fetching daily production' });
  }
});

// Create or update daily production record
router.post('/', async (req, res) => {
  try {
    const {
      id,
      product_name,
      morning_production,
      afternoon_production,
      evening_production,
      production_date,
    } = req.body;

    // Validation
    if (!product_name || !production_date) {
      return res.status(400).json({ message: 'Product name and production date are required' });
    }

    let rows;
    
    // If ID is provided, update existing record by ID
    if (id) {
      const result = await db.query(
        `UPDATE daily_production SET
          product_name = $1, morning_production = $2, afternoon_production = $3,
          evening_production = $4, production_date = $5, updated_at = CURRENT_TIMESTAMP
        WHERE id = $6
        RETURNING *`,
        [
          product_name,
          morning_production || 0,
          afternoon_production || 0,
          evening_production || 0,
          production_date,
          id,
        ]
      );
      rows = result.rows;
      if (rows.length === 0) {
        return res.status(404).json({ message: 'Daily production record not found' });
      }
    } else {
      // Check if record exists for this product and date
      const existingResult = await db.query(
        'SELECT id FROM daily_production WHERE product_name = $1 AND production_date = $2',
        [product_name, production_date]
      );
      
      if (existingResult.rows.length > 0) {
        // Update existing record
        const existingId = existingResult.rows[0].id;
        const result = await db.query(
          `UPDATE daily_production SET
            morning_production = $1, afternoon_production = $2,
            evening_production = $3, updated_at = CURRENT_TIMESTAMP
          WHERE id = $4
          RETURNING *`,
          [
            morning_production || 0,
            afternoon_production || 0,
            evening_production || 0,
            existingId,
          ]
        );
        rows = result.rows;
      } else {
        // Create new record
        const result = await db.query(
          `INSERT INTO daily_production (
            product_name, morning_production, afternoon_production,
            evening_production, production_date
          ) VALUES ($1, $2, $3, $4, $5)
          RETURNING *`,
          [
            product_name,
            morning_production || 0,
            afternoon_production || 0,
            evening_production || 0,
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

