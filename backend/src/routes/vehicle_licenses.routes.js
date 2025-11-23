import { Router } from 'express';
import db from '../db.js';

const router = Router();

// Get vehicle licenses
router.get('/', async (req, res) => {
  try {
    const { sector } = req.query;
    let query = 'SELECT * FROM vehicle_licenses WHERE 1=1';
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
    console.error('Error fetching vehicle licenses:', err);
    res.status(500).json({ message: 'Error fetching vehicle licenses' });
  }
});

// Create or update vehicle license
router.post('/', async (req, res) => {
  try {
    const {
      id,
      sector_code,
      name,
      model,
      registration_number,
      permit_date,
      insurance_date,
      fitness_date,
      pollution_date,
      tax_date,
    } = req.body;

    if (!name || !model || !registration_number) {
      return res.status(400).json({
        message: 'Name, model, and registration number are required'
      });
    }

    if (id) {
      // Update existing record
      const result = await db.query(
        `UPDATE vehicle_licenses SET
          sector_code = $1,
          name = $2,
          model = $3,
          registration_number = $4,
          permit_date = $5,
          insurance_date = $6,
          fitness_date = $7,
          pollution_date = $8,
          tax_date = $9,
          updated_at = CURRENT_TIMESTAMP
        WHERE id = $10
        RETURNING *`,
        [
          sector_code || null,
          name,
          model,
          registration_number,
          permit_date || null,
          insurance_date || null,
          fitness_date || null,
          pollution_date || null,
          tax_date || null,
          id,
        ]
      );

      if (result.rows.length === 0) {
        return res.status(404).json({ message: 'Vehicle license not found' });
      }

      res.status(200).json(result.rows[0]);
    } else {
      // Create new record
      const result = await db.query(
        `INSERT INTO vehicle_licenses (
          sector_code, name, model, registration_number,
          permit_date, insurance_date, fitness_date, pollution_date, tax_date
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
        RETURNING *`,
        [
          sector_code || null,
          name,
          model,
          registration_number,
          permit_date || null,
          insurance_date || null,
          fitness_date || null,
          pollution_date || null,
          tax_date || null,
        ]
      );

      res.status(201).json(result.rows[0]);
    }
  } catch (err) {
    console.error('Error saving vehicle license:', err);
    res.status(500).json({ message: err.message || 'Error saving vehicle license' });
  }
});

// Update vehicle license
router.put('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const {
      sector_code,
      name,
      model,
      registration_number,
      permit_date,
      insurance_date,
      fitness_date,
      pollution_date,
      tax_date,
    } = req.body;

    if (!name || !model || !registration_number) {
      return res.status(400).json({
        message: 'Name, model, and registration number are required'
      });
    }

    const result = await db.query(
      `UPDATE vehicle_licenses SET
        sector_code = $1,
        name = $2,
        model = $3,
        registration_number = $4,
        permit_date = $5,
        insurance_date = $6,
        fitness_date = $7,
        pollution_date = $8,
        tax_date = $9,
        updated_at = CURRENT_TIMESTAMP
      WHERE id = $10
      RETURNING *`,
      [
        sector_code || null,
        name,
        model,
        registration_number,
        permit_date || null,
        insurance_date || null,
        fitness_date || null,
        pollution_date || null,
        tax_date || null,
        id,
      ]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ message: 'Vehicle license not found' });
    }

    res.status(200).json(result.rows[0]);
  } catch (err) {
    console.error('Error updating vehicle license:', err);
    res.status(500).json({ message: err.message || 'Error updating vehicle license' });
  }
});

// Delete vehicle license
router.delete('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const result = await db.query('DELETE FROM vehicle_licenses WHERE id = $1 RETURNING *', [id]);

    if (result.rows.length === 0) {
      return res.status(404).json({ message: 'Vehicle license not found' });
    }

    res.status(204).send();
  } catch (err) {
    console.error('Error deleting vehicle license:', err);
    res.status(500).json({ message: 'Error deleting vehicle license' });
  }
});

export default router;

