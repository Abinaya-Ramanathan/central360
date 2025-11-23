import { Router } from 'express';
import db from '../db.js';

const router = Router();

// Get driver licenses
router.get('/', async (req, res) => {
  try {
    const { sector } = req.query;
    let query = 'SELECT * FROM driver_licenses WHERE 1=1';
    const params = [];
    let paramCount = 1;

    if (sector) {
      query += ` AND sector_code = $${paramCount++}`;
      params.push(sector);
    }

    query += ' ORDER BY id DESC';
    const { rows } = await db.query(query, params);
    res.json(rows);
  } catch (err) {
    console.error('Error fetching driver licenses:', err);
    res.status(500).json({ message: 'Error fetching driver licenses' });
  }
});

// Create or update driver license
router.post('/', async (req, res) => {
  try {
    const {
      id,
      sector_code,
      driver_name,
      license_number,
      expiry_date,
    } = req.body;

    if (!driver_name || !license_number || !expiry_date) {
      return res.status(400).json({
        message: 'Driver name, license number, and expiry date are required'
      });
    }

    if (id) {
      // Update existing record
      const result = await db.query(
        `UPDATE driver_licenses SET
          sector_code = $1,
          driver_name = $2,
          license_number = $3,
          expiry_date = $4,
          updated_at = CURRENT_TIMESTAMP
        WHERE id = $5
        RETURNING *`,
        [
          sector_code || null,
          driver_name,
          license_number,
          expiry_date,
          id,
        ]
      );

      if (result.rows.length === 0) {
        return res.status(404).json({ message: 'Driver license not found' });
      }

      res.status(200).json(result.rows[0]);
    } else {
      // Create new record
      const result = await db.query(
        `INSERT INTO driver_licenses (
          sector_code, driver_name, license_number, expiry_date
        ) VALUES ($1, $2, $3, $4)
        RETURNING *`,
        [
          sector_code || null,
          driver_name,
          license_number,
          expiry_date,
        ]
      );

      res.status(201).json(result.rows[0]);
    }
  } catch (err) {
    console.error('Error saving driver license:', err);
    res.status(500).json({ message: err.message || 'Error saving driver license' });
  }
});

// Update driver license
router.put('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const {
      sector_code,
      driver_name,
      license_number,
      expiry_date,
    } = req.body;

    if (!driver_name || !license_number || !expiry_date) {
      return res.status(400).json({
        message: 'Driver name, license number, and expiry date are required'
      });
    }

    const result = await db.query(
      `UPDATE driver_licenses SET
        sector_code = $1,
        driver_name = $2,
        license_number = $3,
        expiry_date = $4,
        updated_at = CURRENT_TIMESTAMP
      WHERE id = $5
      RETURNING *`,
      [
        sector_code || null,
        driver_name,
        license_number,
        expiry_date,
        id,
      ]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ message: 'Driver license not found' });
    }

    res.status(200).json(result.rows[0]);
  } catch (err) {
    console.error('Error updating driver license:', err);
    res.status(500).json({ message: err.message || 'Error updating driver license' });
  }
});

// Delete driver license
router.delete('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const result = await db.query('DELETE FROM driver_licenses WHERE id = $1 RETURNING *', [id]);

    if (result.rows.length === 0) {
      return res.status(404).json({ message: 'Driver license not found' });
    }

    res.status(204).send();
  } catch (err) {
    console.error('Error deleting driver license:', err);
    res.status(500).json({ message: 'Error deleting driver license' });
  }
});

export default router;

