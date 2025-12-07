import { Router } from 'express';
import db from '../db.js';

const router = Router();

// Get credit details
router.get('/', async (req, res) => {
  try {
    const { sector, date, month, company_staff } = req.query;
    let query = 'SELECT * FROM credit_details WHERE 1=1';
    const params = [];
    let paramCount = 1;

    if (sector) {
      query += ` AND sector_code = $${paramCount++}`;
      params.push(sector);
    }

    if (date) {
      query += ` AND credit_date = $${paramCount++}::date`;
      params.push(date);
    }

    if (month) {
      query += ` AND TO_CHAR(credit_date, 'YYYY-MM') = $${paramCount++}`;
      params.push(month);
    }

    if (company_staff !== undefined && company_staff !== null && company_staff !== '') {
      if (company_staff === 'true' || company_staff === true) {
        query += ` AND company_staff = true`;
      } else if (company_staff === 'false' || company_staff === false) {
        query += ` AND company_staff = false`;
      }
      // If company_staff is 'null' or empty string, don't filter (show all)
    }

    query += ' ORDER BY credit_date DESC, created_at DESC';
    const { rows } = await db.query(query, params);
    res.json(rows);
  } catch (err) {
    console.error('Error fetching credit details:', err);
    res.status(500).json({ message: 'Error fetching credit details' });
  }
});

// Create or update credit details
router.post('/', async (req, res) => {
  try {
    const {
      id,
      sector_code,
      name,
      phone_number,
      address,
      purchase_details,
      credit_amount,
      amount_settled,
      credit_date,
      full_settlement_date,
      comments,
      company_staff,
    } = req.body;

    if (!sector_code || !name || !credit_date) {
      return res.status(400).json({
        message: 'Sector code, name, and credit date are required'
      });
    }

    if (id) {
      // Update existing record
      const result = await db.query(
        `UPDATE credit_details SET
          sector_code = $1,
          name = $2,
          phone_number = $3,
          address = $4,
          purchase_details = $5,
          credit_amount = $6,
          amount_settled = $7,
          credit_date = $8,
          full_settlement_date = $9,
          comments = $10,
          company_staff = $11,
          updated_at = CURRENT_TIMESTAMP
        WHERE id = $12
        RETURNING *`,
        [
          sector_code,
          name,
          phone_number || null,
          address || null,
          purchase_details || null,
          credit_amount || 0,
          amount_settled || 0,
          credit_date,
          full_settlement_date || null,
          comments || null,
          company_staff !== undefined && company_staff !== null ? company_staff : null,
          id,
        ]
      );

      if (result.rows.length === 0) {
        return res.status(404).json({ message: 'Credit details not found' });
      }

      res.status(200).json(result.rows[0]);
    } else {
      // Create new record
      const result = await db.query(
        `INSERT INTO credit_details (
          sector_code, name, phone_number, address, purchase_details,
          credit_amount, amount_settled, credit_date, full_settlement_date, comments, company_staff
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
        RETURNING *`,
        [
          sector_code,
          name,
          phone_number || null,
          address || null,
          purchase_details || null,
          credit_amount || 0,
          amount_settled || 0,
          credit_date,
          full_settlement_date || null,
          comments || null,
          company_staff !== undefined && company_staff !== null ? company_staff : null,
        ]
      );

      res.status(201).json(result.rows[0]);
    }
  } catch (err) {
    console.error('Error saving credit details:', err);
    res.status(500).json({
      message: 'Error saving credit details',
      error: process.env.NODE_ENV === 'development' ? err.message : undefined
    });
  }
});

// Delete credit details
router.delete('/:id', async (req, res) => {
  try {
    const { id } = req.params;

    const result = await db.query(
      'DELETE FROM credit_details WHERE id = $1 RETURNING *',
      [id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ message: 'Credit details not found' });
    }

    res.status(200).json({ message: 'Credit details deleted successfully' });
  } catch (err) {
    console.error('Error deleting credit details:', err);
    res.status(500).json({
      message: 'Error deleting credit details',
      error: process.env.NODE_ENV === 'development' ? err.message : undefined
    });
  }
});

export default router;

