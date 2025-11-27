import { Router } from 'express';
import db from '../db.js';

const router = Router();

// Get sales details
router.get('/', async (req, res) => {
  try {
    const { sector, date, month } = req.query;
    // Use TO_CHAR to format sale_date as string to avoid timezone issues
    let query = `SELECT 
      id, sector_code, name, contact_number, address, product_name, quantity,
      amount_received, credit_amount, amount_pending,
      COALESCE(balance_paid, 0) as balance_paid,
      TO_CHAR(sale_date, 'YYYY-MM-DD') as sale_date,
      TO_CHAR(balance_paid_date, 'YYYY-MM-DD') as balance_paid_date,
      created_at, updated_at
      FROM sales_details WHERE 1=1`;
    const params = [];
    let paramCount = 1;

    if (sector) {
      query += ` AND sector_code = $${paramCount++}`;
      params.push(sector);
    }

    if (date) {
      query += ` AND sale_date = $${paramCount++}::date`;
      params.push(date);
    }

    if (month) {
      query += ` AND TO_CHAR(sale_date, 'YYYY-MM') = $${paramCount++}`;
      params.push(month);
    }

    query += ' ORDER BY sale_date DESC, created_at DESC';
    const { rows } = await db.query(query, params);
    res.json(rows);
  } catch (err) {
    console.error('Error fetching sales details:', err);
    res.status(500).json({ message: 'Error fetching sales details' });
  }
});

// Get credit details (people with credit_amount > 0)
router.get('/credits', async (req, res) => {
  try {
    const { sector } = req.query;
    // Use TO_CHAR to format sale_date as string to avoid timezone issues
    let query = `SELECT 
      id, sector_code, name, contact_number, address, product_name, quantity,
      amount_received, credit_amount, amount_pending,
      COALESCE(balance_paid, 0) as balance_paid,
      TO_CHAR(sale_date, 'YYYY-MM-DD') as sale_date,
      TO_CHAR(balance_paid_date, 'YYYY-MM-DD') as balance_paid_date,
      created_at, updated_at
      FROM sales_details WHERE credit_amount > 0`;
    const params = [];
    let paramCount = 1;

    if (sector) {
      query += ` AND sector_code = $${paramCount++}`;
      params.push(sector);
    }

    query += ' ORDER BY sale_date DESC, created_at DESC';
    console.log(`[Credit Details] Query: ${query}, params:`, params);
    const { rows } = await db.query(query, params);
    console.log(`[Credit Details] Found ${rows.length} records with credit_amount > 0`);
    for (const row of rows) {
      console.log(`  - ${row.name}: sale_date=${row.sale_date}, credit_amount=${row.credit_amount}`);
    }
    res.json(rows);
  } catch (err) {
    console.error('Error fetching credit details from sales:', err);
    res.status(500).json({ message: 'Error fetching credit details' });
  }
});

// Create or update sales details
router.post('/', async (req, res) => {
  try {
    const {
      id,
      sector_code,
      name,
      contact_number,
      address,
      product_name,
      quantity,
      amount_received,
      credit_amount,
      balance_paid,
      balance_paid_date,
      sale_date,
    } = req.body;

    if (!sector_code || !name || !product_name || !quantity || !sale_date) {
      return res.status(400).json({
        message: 'Sector code, name, product name, quantity, and sale date are required'
      });
    }

    // Calculate amount_pending
    const amount_pending = Math.max(0, (credit_amount || 0) - (amount_received || 0));

    if (id) {
      // Update existing record
      console.log(`[Sales Details] Updating record ID ${id} with sale_date: ${sale_date}, credit_amount: ${credit_amount}`);
      const { rows } = await db.query(
        `UPDATE sales_details SET
          sector_code = $1,
          name = $2,
          contact_number = $3,
          address = $4,
          product_name = $5,
          quantity = $6,
          amount_received = $7,
          credit_amount = $8,
          amount_pending = $9,
          balance_paid = $10,
          balance_paid_date = $11,
          sale_date = $12,
          updated_at = CURRENT_TIMESTAMP
        WHERE id = $13
        RETURNING *`,
        [
          sector_code,
          name,
          contact_number || null,
          address || null,
          product_name,
          quantity,
          amount_received || 0,
          credit_amount || 0,
          amount_pending,
          balance_paid || 0,
          balance_paid_date || null,
          sale_date,
          id,
        ]
      );
      console.log(`[Sales Details] Updated record - sale_date: ${rows[0]?.sale_date}, credit_amount: ${rows[0]?.credit_amount}`);

      if (rows.length === 0) {
        return res.status(404).json({ message: 'Sales details not found' });
      }

      res.json(rows[0]);
    } else {
      // Create new record
      const { rows } = await db.query(
        `INSERT INTO sales_details (
          sector_code, name, contact_number, address, product_name, quantity,
          amount_received, credit_amount, amount_pending, balance_paid, balance_paid_date, sale_date
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
        RETURNING *`,
        [
          sector_code,
          name,
          contact_number || null,
          address || null,
          product_name,
          quantity,
          amount_received || 0,
          credit_amount || 0,
          amount_pending,
          balance_paid || 0,
          balance_paid_date || null,
          sale_date,
        ]
      );

      res.status(201).json(rows[0]);
    }
  } catch (err) {
    console.error('Error saving sales details:', err);
    res.status(500).json({
      message: 'Error saving sales details',
      error: err.message,
    });
  }
});

// Delete sales details
router.delete('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { rows } = await db.query(
      'DELETE FROM sales_details WHERE id = $1 RETURNING *',
      [id]
    );

    if (rows.length === 0) {
      return res.status(404).json({ message: 'Sales details not found' });
    }

    res.status(200).json({ message: 'Sales details deleted successfully' });
  } catch (err) {
    console.error('Error deleting sales details:', err);
    res.status(500).json({
      message: 'Error deleting sales details',
      error: err.message,
    });
  }
});

export default router;

