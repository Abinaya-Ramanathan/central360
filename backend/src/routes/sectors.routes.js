import { Router } from 'express';
import db from '../db.js';

const router = Router();

// Get all sectors
router.get('/', async (req, res) => {
  try {
    const { rows } = await db.query('SELECT * FROM sectors ORDER BY code');
    res.json(rows);
  } catch (err) {
    console.error('Sector fetch error:', err.message);
    console.error('Full error:', err);
    res.status(500).json({ 
      message: 'Error fetching sectors',
      error: err.message,
      details: process.env.NODE_ENV === 'development' ? err.stack : undefined
    });
  }
});

// Create sector
router.post('/', async (req, res) => {
  try {
    const { code, name } = req.body;

    // Validation
    if (!code || !code.trim()) {
      return res.status(400).json({ message: 'Sector code is required' });
    }
    if (!name || !name.trim()) {
      return res.status(400).json({ message: 'Sector name is required' });
    }

    const codeUpper = code.trim().toUpperCase();
    const nameTrimmed = name.trim();

    // Check if sector already exists
    try {
      const existing = await db.query('SELECT * FROM sectors WHERE code = $1', [codeUpper]);
      if (existing.rows.length > 0) {
        return res.status(400).json({ message: 'Sector code already exists' });
      }
    } catch (checkErr) {
      console.error('Error checking existing sector:', checkErr);
      // Continue to try insert - might be a connection issue
    }

    const { rows } = await db.query(
      'INSERT INTO sectors (code, name) VALUES ($1, $2) RETURNING *',
      [codeUpper, nameTrimmed]
    );
    res.status(201).json(rows[0]);
  } catch (err) {
    console.error('Error creating sector:', err);
    console.error('Error code:', err.code);
    console.error('Error message:', err.message);
    
    // Handle database constraint violations
    if (err.code === '23505') { // Unique violation
      return res.status(400).json({ message: 'Sector code already exists' });
    }
    
    // Handle other database errors
    if (err.code && err.code.startsWith('23')) { // Other constraint violations
      return res.status(400).json({ 
        message: 'Database constraint violation',
        error: err.message 
      });
    }
    
    // Return more detailed error in production for debugging
    res.status(500).json({ 
      message: 'Error creating sector',
      error: err.message || 'Unknown database error',
      code: err.code || 'UNKNOWN'
    });
  }
});

// Delete sector
router.delete('/:code', async (req, res) => {
  try {
    const { code } = req.params;

    // Check if sector is used by any employees
    const employees = await db.query('SELECT COUNT(*) FROM employees WHERE sector = $1', [code]);
    if (parseInt(employees.rows[0].count) > 0) {
      return res.status(400).json({
        message: 'Cannot delete sector. It is assigned to employees.',
      });
    }

    const { rows } = await db.query(
      'DELETE FROM sectors WHERE code = $1 RETURNING *',
      [code]
    );
    if (rows.length === 0) {
      return res.status(404).json({ message: 'Sector not found' });
    }
    res.json({ message: 'Sector deleted' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Error deleting sector' });
  }
});

export default router;

