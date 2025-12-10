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
      COALESCE(company_staff, false) as company_staff,
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
    const { sector, company_staff, month } = req.query;
    // Use TO_CHAR to format sale_date as string to avoid timezone issues
    let query = `SELECT 
      id, sector_code, name, contact_number, address, product_name, quantity,
      amount_received, credit_amount, amount_pending,
      COALESCE(balance_paid, 0) as balance_paid,
      COALESCE(company_staff, false) as company_staff,
      TO_CHAR(sale_date, 'YYYY-MM-DD') as sale_date,
      TO_CHAR(balance_paid_date, 'YYYY-MM-DD') as balance_paid_date,
      details,
      created_at, updated_at
      FROM sales_details WHERE credit_amount > 0`;
    const params = [];
    let paramCount = 1;

    if (sector) {
      query += ` AND sector_code = $${paramCount++}`;
      params.push(sector);
    }

    if (company_staff !== undefined && company_staff !== null && company_staff !== '') {
      if (company_staff === 'true' || company_staff === true) {
        query += ` AND company_staff = true`;
      } else if (company_staff === 'false' || company_staff === false) {
        // Include both false and NULL values when filtering for "No"
        query += ` AND (company_staff = false OR company_staff IS NULL)`;
      }
      // If company_staff is 'null' or empty string, don't filter (show all)
    }

    if (month) {
      query += ` AND TO_CHAR(sale_date, 'YYYY-MM') = $${paramCount++}`;
      params.push(month);
    }

    query += ' ORDER BY sale_date DESC, created_at DESC';
    console.log(`[Credit Details] Query: ${query}, params:`, params);
    console.log(`[Credit Details] company_staff filter: ${company_staff} (type: ${typeof company_staff})`);
    const { rows } = await db.query(query, params);
    console.log(`[Credit Details] Found ${rows.length} records with credit_amount > 0`);
    
    // Get balance payments for each sale
    for (const row of rows) {
      const saleId = row.id;
      // Get balance payments for this sale
      const paymentsResult = await db.query(
        `SELECT id, balance_paid, TO_CHAR(balance_paid_date, 'YYYY-MM-DD') as balance_paid_date, 
         details, overall_balance, created_at, updated_at 
         FROM sales_balance_payments 
         WHERE sale_id = $1 
         ORDER BY created_at ASC`,
        [saleId]
      );
      row.balance_payments = paymentsResult.rows;
      console.log(`  - ${row.name}: sale_date=${row.sale_date}, credit_amount=${row.credit_amount}, payments=${paymentsResult.rows.length}`);
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
      details,
      company_staff,
    } = req.body;

    if (!sector_code || !product_name || !quantity || !sale_date) {
      return res.status(400).json({
        message: 'Sector code, product name, quantity, and sale date are required'
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
          details = $12,
          sale_date = $13,
          company_staff = $14,
          updated_at = CURRENT_TIMESTAMP
        WHERE id = $15
        RETURNING *`,
        [
          sector_code,
          name || null,
          contact_number || null,
          address || null,
          product_name,
          quantity,
          amount_received || 0,
          credit_amount || 0,
          amount_pending,
          balance_paid || 0,
          balance_paid_date || null,
          details || null,
          sale_date,
          company_staff || false,
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
          amount_received, credit_amount, amount_pending, balance_paid, balance_paid_date, details, sale_date, company_staff
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
        RETURNING *`,
        [
          sector_code,
          name || null,
          contact_number || null,
          address || null,
          product_name,
          quantity,
          amount_received || 0,
          credit_amount || 0,
          amount_pending,
          balance_paid || 0,
          balance_paid_date || null,
          details || null,
          sale_date,
          company_staff || false,
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

// Get balance payments for a sale
router.get('/:id/balance-payments', async (req, res) => {
  try {
    const { id } = req.params;
    const { rows } = await db.query(
      `SELECT id, balance_paid, TO_CHAR(balance_paid_date, 'YYYY-MM-DD') as balance_paid_date, 
       details, overall_balance, created_at, updated_at 
       FROM sales_balance_payments 
       WHERE sale_id = $1 
       ORDER BY created_at ASC`,
      [id]
    );
    res.json(rows);
  } catch (err) {
    console.error('Error fetching balance payments:', err);
    res.status(500).json({ message: 'Error fetching balance payments' });
  }
});

// Create or update a balance payment
router.post('/balance-payments', async (req, res) => {
  try {
    const {
      id,
      sale_id,
      balance_paid,
      balance_paid_date,
      details,
      overall_balance,
    } = req.body;

    if (!sale_id) {
      return res.status(400).json({ message: 'sale_id is required' });
    }

    if (id) {
      // Update existing balance payment
      const { rows } = await db.query(
        `UPDATE sales_balance_payments SET
          balance_paid = $1,
          balance_paid_date = $2,
          details = $3,
          overall_balance = $4,
          updated_at = CURRENT_TIMESTAMP
        WHERE id = $5
        RETURNING id, balance_paid, TO_CHAR(balance_paid_date, 'YYYY-MM-DD') as balance_paid_date, 
                   details, overall_balance, created_at, updated_at`,
        [
          balance_paid || 0,
          balance_paid_date || null,
          details || null,
          overall_balance || 0,
          id,
        ]
      );

      if (rows.length === 0) {
        return res.status(404).json({ message: 'Balance payment not found' });
      }

      res.json(rows[0]);
    } else {
      // Create new balance payment
      const { rows } = await db.query(
        `INSERT INTO sales_balance_payments (
          sale_id, balance_paid, balance_paid_date, details, overall_balance
        ) VALUES ($1, $2, $3, $4, $5)
        RETURNING id, balance_paid, TO_CHAR(balance_paid_date, 'YYYY-MM-DD') as balance_paid_date, 
                   details, overall_balance, created_at, updated_at`,
        [
          sale_id,
          balance_paid || 0,
          balance_paid_date || null,
          details || null,
          overall_balance || 0,
        ]
      );

      res.status(201).json(rows[0]);
    }
  } catch (err) {
    console.error('Error saving balance payment:', err);
    res.status(500).json({
      message: 'Error saving balance payment',
      error: err.message,
    });
  }
});

// Delete a balance payment
router.delete('/balance-payments/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { rows } = await db.query(
      'DELETE FROM sales_balance_payments WHERE id = $1 RETURNING *',
      [id]
    );

    if (rows.length === 0) {
      return res.status(404).json({ message: 'Balance payment not found' });
    }

    res.status(200).json({ message: 'Balance payment deleted successfully' });
  } catch (err) {
    console.error('Error deleting balance payment:', err);
    res.status(500).json({
      message: 'Error deleting balance payment',
      error: err.message,
    });
  }
});

export default router;

