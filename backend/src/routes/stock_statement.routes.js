import { Router } from 'express';
import db from '../db.js';

const router = Router();

// Generate stock statement
router.post('/generate', async (req, res) => {
  try {
    const { from_date, to_date, sector } = req.body;

    if (!from_date || !to_date) {
      return res.status(400).json({ message: 'From date and To date are required' });
    }

    let query = `
      SELECT 
        si.item_name,
        COALESCE(SUM(CAST(ds.quantity_taken AS DECIMAL)), 0) as stocks_used,
        si.sector_code,
        s.name as sector_name
      FROM stock_items si
      LEFT JOIN daily_stock ds ON si.id = ds.item_id 
        AND ds.stock_date >= $1 
        AND ds.stock_date <= $2
      JOIN sectors s ON si.sector_code = s.code
      WHERE 1=1
    `;
    const params = [from_date, to_date];
    let paramCount = 3;

    if (sector) {
      query += ` AND si.sector_code = $${paramCount++}`;
      params.push(sector);
    }

    query += ' GROUP BY si.id, si.item_name, si.sector_code, s.name ORDER BY si.sector_code, si.item_name';

    const { rows } = await db.query(query, params);
    res.json(rows);
  } catch (err) {
    console.error('Error generating stock statement:', err);
    res.status(500).json({ message: 'Error generating stock statement' });
  }
});

export default router;

