import { Router } from 'express';
import db from '../db.js';

const router = Router();

// Get all employees
router.get('/', async (req, res) => {
  try {
    const startTime = Date.now();
    // Optimized query: Only select needed columns, use index on name
    const { rows } = await db.query(
      'SELECT id, name, contact, contact2, address, bank_details, sector, role, daily_salary, weekly_salary, monthly_salary, joining_date, joining_year, created_at, updated_at FROM employees ORDER BY name ASC'
    );
    const queryTime = Date.now() - startTime;
    console.log(`[Performance] Employees query took ${queryTime}ms, returned ${rows.length} records`);
    res.json(rows);
  } catch (err) {
    console.error('Error fetching employees:', err);
    res.status(500).json({ message: 'Error fetching employees' });
  }
});

// Get employees by sector
router.get('/sector/:sectorCode', async (req, res) => {
  try {
    const { sectorCode } = req.params;
    const startTime = Date.now();
    // Optimized query: Use index on sector, only select needed columns
    const { rows } = await db.query(
      'SELECT id, name, contact, contact2, address, bank_details, sector, role, daily_salary, weekly_salary, monthly_salary, joining_date, joining_year, created_at, updated_at FROM employees WHERE sector = $1 ORDER BY name ASC',
      [sectorCode]
    );
    const queryTime = Date.now() - startTime;
    console.log(`[Performance] Employees by sector query took ${queryTime}ms, returned ${rows.length} records`);
    res.json(rows);
  } catch (err) {
    console.error('Error fetching employees by sector:', err);
    res.status(500).json({ message: 'Error fetching employees by sector' });
  }
});

// Create employee
router.post('/', async (req, res) => {
  try {
    const {
      name,
      contact,
      contact2,
      address,
      bank_details,
      sector,
      role,
      daily_salary,
      weekly_salary,
      monthly_salary,
      joining_date,
      joining_year,
    } = req.body;

    // Validation
    if (!name || !name.trim()) {
      return res.status(400).json({ message: 'Employee name is required' });
    }
    if (!contact || !contact.trim()) {
      return res.status(400).json({ message: 'Contact number is required' });
    }
    if (!sector || !sector.trim()) {
      return res.status(400).json({ message: 'Sector is required' });
    }

    // Verify sector exists
    const sectorCheck = await db.query('SELECT * FROM sectors WHERE code = $1', [sector]);
    if (sectorCheck.rows.length === 0) {
      return res.status(400).json({ message: `Sector "${sector}" does not exist. Please create the sector first.` });
    }

    const { rows } = await db.query(
      `INSERT INTO employees (
        name, contact, contact2, address, bank_details, sector, role,
        daily_salary, weekly_salary, monthly_salary, joining_date, joining_year
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
      RETURNING *`,
      [
        name.trim(),
        contact.trim(),
        contact2?.trim() || '',
        address?.trim() || '',
        bank_details?.trim() || '',
        sector.trim(),
        role?.trim() || '',
        daily_salary || 0,
        weekly_salary || 0,
        monthly_salary || 0,
        joining_date || null,
        joining_year || null,
      ]
    );
    res.status(201).json(rows[0]);
  } catch (err) {
    console.error('Error creating employee:', err);
    console.error('Error details:', {
      code: err.code,
      message: err.message,
      detail: err.detail,
      body: req.body
    });
    // Handle database constraint violations
    if (err.code === '23503') { // Foreign key violation
      return res.status(400).json({ 
        message: `Sector does not exist. Please create the sector first.` 
      });
    }
    if (err.code === '23505') { // Unique violation
      return res.status(400).json({ 
        message: `Employee with this information already exists.` 
      });
    }
    res.status(500).json({ 
      message: 'Error creating employee',
      error: process.env.NODE_ENV === 'development' ? err.message : undefined
    });
  }
});

// Update employee
router.put('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const {
      name,
      contact,
      contact2,
      address,
      bank_details,
      sector,
      role,
      daily_salary,
      weekly_salary,
      monthly_salary,
      joining_date,
      joining_year,
    } = req.body;

    const { rows } = await db.query(
      `UPDATE employees SET
        name = $1, contact = $2, contact2 = $3, address = $4, bank_details = $5,
        sector = $6, role = $7, daily_salary = $8, weekly_salary = $9,
        monthly_salary = $10, joining_date = $11, joining_year = $12
      WHERE id = $13
      RETURNING *`,
      [
        name,
        contact,
        contact2 || '',
        address || '',
        bank_details || '',
        sector,
        role || '',
        daily_salary || 0,
        weekly_salary || 0,
        monthly_salary || 0,
        joining_date || null,
        joining_year || null,
        id,
      ]
    );
    if (rows.length === 0) {
      return res.status(404).json({ message: 'Employee not found' });
    }
    res.json(rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Error updating employee' });
  }
});

// Delete employee
router.delete('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { rows } = await db.query(
      'DELETE FROM employees WHERE id = $1 RETURNING *',
      [id]
    );
    if (rows.length === 0) {
      return res.status(404).json({ message: 'Employee not found' });
    }
    res.json({ message: 'Employee deleted' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Error deleting employee' });
  }
});

export default router;

