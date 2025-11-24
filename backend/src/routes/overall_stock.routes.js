import { Router } from 'express';
import db from '../db.js';

const router = Router();

// Get overall stock records
router.get('/', async (req, res) => {
  try {
    const { month, date, sector } = req.query;
    let query = `
      SELECT 
        os.*, 
        si.item_name, 
        si.sector_code, 
        si.vehicle_type, 
        si.part_number, 
        s.name as sector_name,
        COALESCE(SUM(CAST(ds.quantity_taken AS DECIMAL)), 0) as total_taken
      FROM overall_stock os
      JOIN stock_items si ON os.item_id = si.id
      JOIN sectors s ON si.sector_code = s.code
      LEFT JOIN daily_stock ds ON os.item_id = ds.item_id
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

    query += ' GROUP BY os.id, si.id, s.name ORDER BY si.sector_code, si.item_name';
    const { rows } = await db.query(query, params);
    
    // Calculate remaining stock = new_stock - total_taken
    const processedRows = rows.map(row => {
      const newStock = parseFloat(row.new_stock || '0');
      const totalTaken = parseFloat(row.total_taken || '0');
      const remainingStock = newStock - totalTaken;
      return {
        ...row,
        remaining_stock: remainingStock.toString(),
      };
    });
    
    res.json(processedRows);
  } catch (err) {
    console.error('Error fetching overall stock:', err);
    res.status(500).json({ message: 'Error fetching overall stock' });
  }
});

// Update overall stock records
router.put('/', async (req, res) => {
  try {
    const { updates } = req.body;
    const { date } = req.query;

    if (!Array.isArray(updates)) {
      return res.status(400).json({ message: 'Updates must be an array' });
    }

    const results = [];
    for (const update of updates) {
      const { id, item_id, new_stock } = update;

      // Get item_id - either from update or from existing record
      let finalItemId = item_id;
      if (!finalItemId && id) {
        // If we have id but no item_id, get item_id from existing record
        const existing = await db.query('SELECT item_id FROM overall_stock WHERE id = $1', [id]);
        if (existing.rows.length > 0) {
          finalItemId = existing.rows[0].item_id;
        }
      }

      if (!finalItemId) {
        continue; // Skip if we can't determine item_id
      }

      // Get total quantity taken from daily_stock for this item up to the selected date
      let dailyStockQuery;
      if (date) {
        dailyStockQuery = await db.query(
          'SELECT COALESCE(SUM(CAST(quantity_taken AS DECIMAL)), 0) as total_taken FROM daily_stock WHERE item_id = $1 AND stock_date <= $2',
          [finalItemId, date]
        );
      } else {
        dailyStockQuery = await db.query(
          'SELECT COALESCE(SUM(CAST(quantity_taken AS DECIMAL)), 0) as total_taken FROM daily_stock WHERE item_id = $1',
          [finalItemId]
        );
      }
      const totalTaken = parseFloat(dailyStockQuery.rows[0]?.total_taken || '0');
      
      const newStockValue = parseFloat(new_stock || '0');
      const updatedRemaining = newStockValue - totalTaken;

      // Use UPSERT to handle both insert and update
      // Since item_id has a UNIQUE constraint, we can use ON CONFLICT
      const result = await db.query(
        `INSERT INTO overall_stock (item_id, remaining_stock, new_stock) 
         VALUES ($1, $2, $3) 
         ON CONFLICT (item_id) 
         DO UPDATE SET 
           new_stock = EXCLUDED.new_stock,
           remaining_stock = EXCLUDED.remaining_stock,
           updated_at = CURRENT_TIMESTAMP
         RETURNING *`,
        [finalItemId, updatedRemaining.toString(), new_stock || '0']
      );
      results.push(result.rows[0]);
    }

    res.json(results);
  } catch (err) {
    console.error('Error updating overall stock:', err);
    res.status(500).json({
      message: 'Error updating overall stock',
      error: process.env.NODE_ENV === 'development' ? err.message : undefined
    });
  }
});

export default router;

