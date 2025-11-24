import { Router } from 'express';
import db from '../db.js';

const router = Router();

// Get daily stock records
router.get('/', async (req, res) => {
  try {
    const { month, date, sector } = req.query;
    let query = `
      SELECT ds.*, si.item_name, si.sector_code, si.vehicle_type, si.part_number, s.name as sector_name
      FROM daily_stock ds
      JOIN stock_items si ON ds.item_id = si.id
      JOIN sectors s ON si.sector_code = s.code
      WHERE 1=1
    `;
    const params = [];
    let paramCount = 1;

    if (month) {
      query += ` AND EXTRACT(MONTH FROM ds.stock_date) = $${paramCount++}`;
      params.push(parseInt(month));
    }
    if (date) {
      query += ` AND ds.stock_date = $${paramCount++}`;
      params.push(date);
    }
    if (sector) {
      query += ` AND si.sector_code = $${paramCount++}`;
      params.push(sector);
    }

    query += ' ORDER BY si.sector_code, si.item_name, ds.stock_date';
    const { rows } = await db.query(query, params);
    res.json(rows);
  } catch (err) {
    console.error('Error fetching daily stock:', err);
    res.status(500).json({ message: 'Error fetching daily stock' });
  }
});

// Update daily stock records
router.put('/', async (req, res) => {
  try {
    const { updates } = req.body;
    const { date } = req.query;

    if (!Array.isArray(updates)) {
      return res.status(400).json({ message: 'Updates must be an array' });
    }

    const results = [];
    for (const update of updates) {
      const { id, item_id, quantity_taken, reason } = update;

      if (!item_id) {
        continue;
      }

      // Get the date from query or use current date
      const { date } = req.query;
      const stockDate = date || new Date().toISOString().split('T')[0];

      if (id) {
        // Update existing record
        const existing = await db.query('SELECT * FROM daily_stock WHERE id = $1', [id]);
        if (existing.rows.length > 0) {
          const result = await db.query(
            'UPDATE daily_stock SET quantity_taken = $1, reason = $2, updated_at = CURRENT_TIMESTAMP WHERE id = $3 RETURNING *',
            [quantity_taken || '0', reason || '', id]
          );
          results.push(result.rows[0]);
        }
      } else {
        // Create new record - check if one exists for this item and date
        const existing = await db.query(
          'SELECT * FROM daily_stock WHERE item_id = $1 AND stock_date = $2',
          [item_id, stockDate]
        );
        
        if (existing.rows.length > 0) {
          // Update existing record
          const result = await db.query(
            'UPDATE daily_stock SET quantity_taken = $1, reason = $2, updated_at = CURRENT_TIMESTAMP WHERE id = $3 RETURNING *',
            [quantity_taken || '0', reason || '', existing.rows[0].id]
          );
          results.push(result.rows[0]);
        } else {
          // Create new record
          const result = await db.query(
            'INSERT INTO daily_stock (item_id, quantity_taken, reason, stock_date) VALUES ($1, $2, $3, $4) RETURNING *',
            [item_id, quantity_taken || '0', reason || '', stockDate]
          );
          results.push(result.rows[0]);
        }
      }
    }

    res.json(results);
  } catch (err) {
    console.error('Error updating daily stock:', err);
    res.status(500).json({
      message: 'Error updating daily stock',
      error: process.env.NODE_ENV === 'development' ? err.message : undefined
    });
  }
});

export default router;

