import { Router } from 'express';
import db from '../db.js';

const router = Router();

// Get all rent vehicles (optionally filtered by sector)
router.get('/', async (req, res) => {
  try {
    const { sector } = req.query;
    let query = 'SELECT * FROM rent_vehicles WHERE 1=1';
    const params = [];
    let paramCount = 1;

    if (sector) {
      query += ` AND sector_code = $${paramCount++}`;
      params.push(sector);
    }

    query += ' ORDER BY vehicle_name';
    const { rows } = await db.query(query, params);
    res.json(rows);
  } catch (err) {
    console.error('Error fetching rent vehicles:', err);
    res.status(500).json({ message: 'Error fetching rent vehicles' });
  }
});

// Create a new rent vehicle
router.post('/', async (req, res) => {
  try {
    const { vehicle_name, sector_code } = req.body;

    // Validation
    if (!vehicle_name || !vehicle_name.trim()) {
      return res.status(400).json({ message: 'Vehicle name is required' });
    }
    if (!sector_code) {
      return res.status(400).json({ message: 'Sector code is required' });
    }

    // Check if sector exists
    const sectorCheck = await db.query('SELECT code FROM sectors WHERE code = $1', [sector_code]);
    if (sectorCheck.rows.length === 0) {
      return res.status(404).json({ message: 'Sector not found' });
    }

    // Check if vehicle already exists for this sector
    const existingCheck = await db.query(
      'SELECT id FROM rent_vehicles WHERE vehicle_name = $1 AND sector_code = $2',
      [vehicle_name.trim(), sector_code]
    );
    if (existingCheck.rows.length > 0) {
      return res.status(400).json({ message: 'Vehicle already exists for this sector' });
    }

    const result = await db.query(
      'INSERT INTO rent_vehicles (vehicle_name, sector_code) VALUES ($1, $2) RETURNING *',
      [vehicle_name.trim(), sector_code]
    );

    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error('Error creating rent vehicle:', err);
    if (err.code === '23505') {
      // Unique constraint violation
      return res.status(400).json({ message: 'Vehicle already exists for this sector' });
    }
    res.status(500).json({
      message: 'Error creating rent vehicle',
      error: process.env.NODE_ENV === 'development' ? err.message : undefined
    });
  }
});

// Update a rent vehicle
router.put('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { vehicle_name, sector_code } = req.body;

    if (!vehicle_name || !vehicle_name.trim()) {
      return res.status(400).json({ message: 'Vehicle name is required' });
    }
    if (!sector_code) {
      return res.status(400).json({ message: 'Sector code is required' });
    }

    // Check if sector exists
    const sectorCheck = await db.query('SELECT code FROM sectors WHERE code = $1', [sector_code]);
    if (sectorCheck.rows.length === 0) {
      return res.status(404).json({ message: 'Sector not found' });
    }

    // Check if vehicle name already exists for this sector (excluding current vehicle)
    const existingCheck = await db.query(
      'SELECT id FROM rent_vehicles WHERE vehicle_name = $1 AND sector_code = $2 AND id != $3',
      [vehicle_name.trim(), sector_code, id]
    );
    if (existingCheck.rows.length > 0) {
      return res.status(400).json({ message: 'Vehicle already exists for this sector' });
    }

    const result = await db.query(
      'UPDATE rent_vehicles SET vehicle_name = $1, sector_code = $2, updated_at = CURRENT_TIMESTAMP WHERE id = $3 RETURNING *',
      [vehicle_name.trim(), sector_code, id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ message: 'Rent vehicle not found' });
    }

    res.json(result.rows[0]);
  } catch (err) {
    console.error('Error updating rent vehicle:', err);
    if (err.code === '23505') {
      return res.status(400).json({ message: 'Vehicle already exists for this sector' });
    }
    res.status(500).json({
      message: 'Error updating rent vehicle',
      error: process.env.NODE_ENV === 'development' ? err.message : undefined
    });
  }
});

// Delete a rent vehicle
router.delete('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const result = await db.query('DELETE FROM rent_vehicles WHERE id = $1 RETURNING *', [id]);

    if (result.rows.length === 0) {
      return res.status(404).json({ message: 'Rent vehicle not found' });
    }

    res.status(200).json({ message: 'Rent vehicle deleted successfully' });
  } catch (err) {
    console.error('Error deleting rent vehicle:', err);
    res.status(500).json({
      message: 'Error deleting rent vehicle',
      error: process.env.NODE_ENV === 'development' ? err.message : undefined
    });
  }
});

export default router;

