import { Router } from 'express';
import db from '../db.js';

const router = Router();

// Get daily income/expense records
router.get('/', async (req, res) => {
  try {
    const startTime = Date.now();
    const { sector, date } = req.query;
    
    if (!sector || !date) {
      return res.status(400).json({
        message: 'Sector code and date are required'
      });
    }

    // Optimized: Only select needed columns
    const { rows } = await db.query(
      'SELECT id, sector_code, item_name, quantity, income_amount, expense_amount, entry_date, created_at, updated_at FROM daily_income_expense WHERE sector_code = $1 AND entry_date = $2::date ORDER BY created_at ASC',
      [sector, date]
    );
    
    const duration = Date.now() - startTime;
    console.log(`[Performance] Daily income/expense query took ${duration}ms, returned ${rows.length} records`);
    res.json(rows);
  } catch (err) {
    console.error('Error fetching daily income/expense:', err);
    res.status(500).json({ message: 'Error fetching daily income/expense' });
  }
});

// Create or update daily income/expense record
router.post('/', async (req, res) => {
  try {
    const {
      id,
      sector_code,
      item_name,
      quantity,
      income_amount,
      expense_amount,
      entry_date,
    } = req.body;

    if (!sector_code || !entry_date) {
      return res.status(400).json({
        message: 'Sector code and entry date are required'
      });
    }

    if (id) {
      // Update existing record
      const { rows } = await db.query(
        `UPDATE daily_income_expense SET
          item_name = $1,
          quantity = $2,
          income_amount = $3,
          expense_amount = $4,
          updated_at = CURRENT_TIMESTAMP
        WHERE id = $5
        RETURNING *`,
        [
          item_name || null,
          quantity || null,
          income_amount || 0,
          expense_amount || 0,
          id,
        ]
      );

      if (rows.length === 0) {
        return res.status(404).json({ message: 'Record not found' });
      }

      res.json(rows[0]);
    } else {
      // Create new record
      const { rows } = await db.query(
        `INSERT INTO daily_income_expense (
          sector_code, item_name, quantity, income_amount, expense_amount, entry_date
        ) VALUES ($1, $2, $3, $4, $5, $6)
        RETURNING *`,
        [
          sector_code,
          item_name || null,
          quantity || null,
          income_amount || 0,
          expense_amount || 0,
          entry_date,
        ]
      );

      res.status(201).json(rows[0]);
    }
  } catch (err) {
    console.error('Error saving daily income/expense:', err);
    res.status(500).json({
      message: 'Error saving daily income/expense',
      error: process.env.NODE_ENV === 'development' ? err.message : undefined
    });
  }
});

// Delete daily income/expense record
router.delete('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    
    const result = await db.query(
      'DELETE FROM daily_income_expense WHERE id = $1 RETURNING *',
      [id]
    );
    
    if (result.rows.length === 0) {
      return res.status(404).json({ message: 'Record not found' });
    }
    
    res.status(200).json({ message: 'Record deleted successfully' });
  } catch (err) {
    console.error('Error deleting daily income/expense:', err);
    res.status(500).json({ 
      message: 'Error deleting daily income/expense',
      error: process.env.NODE_ENV === 'development' ? err.message : undefined
    });
  }
});

// Get overall income/expense aggregated by sector
router.get('/overall', async (req, res) => {
  try {
    const startTime = Date.now();
    let { dates, months } = req.query;
    
    let dateArray = [];
    let monthArray = [];
    
    // Handle both single values and arrays
    if (dates) {
      if (Array.isArray(dates)) {
        dateArray = dates;
      } else if (typeof dates === 'string') {
        // Handle comma-separated string
        dateArray = dates.split(',').map(d => d.trim()).filter(d => d);
      } else {
        dateArray = [dates];
      }
    }
    
    if (months) {
      if (Array.isArray(months)) {
        monthArray = months;
      } else if (typeof months === 'string') {
        // Handle comma-separated string
        monthArray = months.split(',').map(m => m.trim()).filter(m => m);
      } else {
        monthArray = [months];
      }
    }

    if (dateArray.length === 0 && monthArray.length === 0) {
      return res.json([]);
    }

    let query = `
      SELECT 
        s.name as sector_name,
        s.code as sector_code,
        COALESCE(SUM(die.income_amount), 0) as total_income,
        COALESCE(SUM(die.expense_amount), 0) as total_expense
      FROM sectors s
      LEFT JOIN daily_income_expense die ON s.code = die.sector_code
      WHERE 1=1
    `;
    
    const params = [];
    let paramCount = 1;
    const conditions = [];

    // Add date conditions
    if (dateArray.length > 0) {
      conditions.push(`die.entry_date = ANY($${paramCount}::date[])`);
      params.push(dateArray);
      paramCount++;
    }

    // Add month conditions
    if (monthArray.length > 0) {
      monthArray.forEach((month) => {
        conditions.push(`TO_CHAR(die.entry_date, 'YYYY-MM') = $${paramCount}`);
        params.push(month);
        paramCount++;
      });
    }

    if (conditions.length > 0) {
      query += ` AND (${conditions.join(' OR ')})`;
    }

    query += `
      GROUP BY s.code, s.name
      HAVING COALESCE(SUM(die.income_amount), 0) > 0 OR COALESCE(SUM(die.expense_amount), 0) > 0
      ORDER BY s.name
    `;

    const { rows } = await db.query(query, params);
    
    const duration = Date.now() - startTime;
    console.log(`[Performance] Overall income/expense query took ${duration}ms, returned ${rows.length} records`);
    
    res.json(rows);
  } catch (err) {
    console.error('Error fetching overall income/expense:', err);
    res.status(500).json({ message: 'Error fetching overall income/expense' });
  }
});

export default router;

