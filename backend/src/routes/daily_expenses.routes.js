import { Router } from 'express';
import db from '../db.js';

const router = Router();

// Get daily expense records
router.get('/', async (req, res) => {
  try {
    const startTime = Date.now();
    const { month, date, sector } = req.query;
    // Optimized: Only select needed columns
    let query = 'SELECT id, item_details, amount, reason_for_purchase, expense_date, sector_code, created_at, updated_at FROM daily_expenses WHERE 1=1';
    const params = [];
    let paramCount = 1;

    if (sector) {
      query += ` AND sector_code = $${paramCount++}`;
      params.push(sector);
    }
    if (month) {
      // Filter by month (YYYY-MM format)
      query += ` AND DATE_TRUNC('month', expense_date) = $${paramCount++}::date`;
      params.push(month + '-01');
    }
    if (date) {
      // Filter by specific date
      query += ` AND expense_date = $${paramCount++}::date`;
      params.push(date);
    }

    query += ' ORDER BY expense_date DESC, item_details';
    const { rows } = await db.query(query, params);
    const duration = Date.now() - startTime;
    console.log(`[Performance] Daily expenses query took ${duration}ms, returned ${rows.length} records`);
    res.json(rows);
  } catch (err) {
    console.error('Error fetching daily expenses:', err);
    res.status(500).json({ message: 'Error fetching daily expenses' });
  }
});

// Create or update daily expense record
router.post('/', async (req, res) => {
  try {
    const {
      id,
      item_details,
      amount,
      reason_for_purchase,
      expense_date,
      sector_code,
    } = req.body;

    // Validation
    if (!sector_code) {
      return res.status(400).json({ message: 'Sector code is required' });
    }

    // Check if sector exists
    const sectorCheck = await db.query('SELECT code FROM sectors WHERE code = $1', [sector_code]);
    if (sectorCheck.rows.length === 0) {
      return res.status(404).json({ message: 'Sector not found' });
    }

    let rows;
    
    // If ID is provided, update existing record
    if (id) {
      const result = await db.query(
        `UPDATE daily_expenses SET
          item_details = $1, amount = $2, reason_for_purchase = $3,
          expense_date = $4, sector_code = $5, updated_at = CURRENT_TIMESTAMP
        WHERE id = $6
        RETURNING *`,
        [
          item_details,
          amount || 0,
          reason_for_purchase || null,
          expense_date,
          sector_code,
          id,
        ]
      );
      rows = result.rows;
      if (rows.length === 0) {
        return res.status(404).json({ message: 'Expense record not found' });
      }
    } else {
      // Create new record
      const result = await db.query(
        `INSERT INTO daily_expenses (
          item_details, amount, reason_for_purchase, expense_date, sector_code
        ) VALUES ($1, $2, $3, $4, $5)
        RETURNING *`,
        [
          item_details,
          amount || 0,
          reason_for_purchase || null,
          expense_date,
          sector_code,
        ]
      );
      rows = result.rows;
    }

    res.status(201).json(rows[0]);
  } catch (err) {
    console.error('Error saving daily expense:', err);
    res.status(500).json({ 
      message: 'Error saving daily expense',
      error: process.env.NODE_ENV === 'development' ? err.message : undefined
    });
  }
});

// Delete daily expense record
router.delete('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    
    const result = await db.query(
      'DELETE FROM daily_expenses WHERE id = $1 RETURNING *',
      [id]
    );
    
    if (result.rows.length === 0) {
      return res.status(404).json({ message: 'Expense record not found' });
    }
    
    res.status(200).json({ message: 'Expense record deleted successfully' });
  } catch (err) {
    console.error('Error deleting daily expense:', err);
    res.status(500).json({ 
      message: 'Error deleting daily expense',
      error: process.env.NODE_ENV === 'development' ? err.message : undefined
    });
  }
});

export default router;

