import { Router } from 'express';
import db from '../db.js';

const router = Router();

// Get contract employees
router.get('/', async (req, res) => {
  try {
    const { date } = req.query;
    let query = 'SELECT * FROM contract_employees WHERE 1=1';
    const params = [];
    let paramCount = 1;

    if (date) {
      query += ` AND date = $${paramCount++}`;
      params.push(date);
    }

    query += ' ORDER BY date DESC, name';
    const { rows } = await db.query(query, params);
    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Error fetching contract employees' });
  }
});

// Create contract employee
router.post('/', async (req, res) => {
  try {
    const {
      name,
      members_count,
      reason,
      salary_per_count,
      total_salary,
      date,
    } = req.body;

    // Validation
    if (!name || !name.trim()) {
      return res.status(400).json({ message: 'Name is required' });
    }
    if (!members_count || members_count < 1) {
      return res.status(400).json({ message: 'Members count must be at least 1' });
    }
    if (!salary_per_count || salary_per_count < 0) {
      return res.status(400).json({ message: 'Salary per count must be 0 or greater' });
    }
    if (!total_salary || total_salary < 0) {
      return res.status(400).json({ message: 'Total salary must be 0 or greater' });
    }
    if (!date) {
      return res.status(400).json({ message: 'Date is required' });
    }

    const { rows } = await db.query(
      `INSERT INTO contract_employees (
        name, members_count, reason, salary_per_count, total_salary, date
      ) VALUES ($1, $2, $3, $4, $5, $6)
      RETURNING *`,
      [
        name.trim(),
        parseInt(members_count),
        reason?.trim() || '',
        parseFloat(salary_per_count),
        parseFloat(total_salary),
        date,
      ]
    );
    res.status(201).json(rows[0]);
  } catch (err) {
    console.error('Error creating contract employee:', err);
    res.status(500).json({
      message: 'Error creating contract employee',
      error: process.env.NODE_ENV === 'development' ? err.message : undefined
    });
  }
});

// Update contract employee
router.put('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const {
      name,
      members_count,
      reason,
      salary_per_count,
      total_salary,
      date,
    } = req.body;

    // Validation
    if (!name || !name.trim()) {
      return res.status(400).json({ message: 'Name is required' });
    }
    if (!members_count || members_count < 1) {
      return res.status(400).json({ message: 'Members count must be at least 1' });
    }
    if (!salary_per_count || salary_per_count < 0) {
      return res.status(400).json({ message: 'Salary per count must be 0 or greater' });
    }
    if (!total_salary || total_salary < 0) {
      return res.status(400).json({ message: 'Total salary must be 0 or greater' });
    }
    if (!date) {
      return res.status(400).json({ message: 'Date is required' });
    }

    const { rows } = await db.query(
      `UPDATE contract_employees SET
        name = $1, members_count = $2, reason = $3,
        salary_per_count = $4, total_salary = $5, date = $6,
        updated_at = CURRENT_TIMESTAMP
      WHERE id = $7
      RETURNING *`,
      [
        name.trim(),
        parseInt(members_count),
        reason?.trim() || '',
        parseFloat(salary_per_count),
        parseFloat(total_salary),
        date,
        parseInt(id),
      ]
    );

    if (rows.length === 0) {
      return res.status(404).json({ message: 'Contract employee not found' });
    }

    res.json(rows[0]);
  } catch (err) {
    console.error('Error updating contract employee:', err);
    res.status(500).json({
      message: 'Error updating contract employee',
      error: process.env.NODE_ENV === 'development' ? err.message : undefined
    });
  }
});

// Delete contract employee
router.delete('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { rows } = await db.query(
      'DELETE FROM contract_employees WHERE id = $1 RETURNING *',
      [id]
    );

    if (rows.length === 0) {
      return res.status(404).json({ message: 'Contract employee not found' });
    }

    res.json({ message: 'Contract employee deleted successfully' });
  } catch (err) {
    console.error('Error deleting contract employee:', err);
    res.status(500).json({
      message: 'Error deleting contract employee',
      error: process.env.NODE_ENV === 'development' ? err.message : undefined
    });
  }
});

export default router;

