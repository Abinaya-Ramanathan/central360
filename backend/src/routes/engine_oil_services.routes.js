import { Router } from 'express';
import db from '../db.js';

const router = Router();

// Get engine oil services
router.get('/', async (req, res) => {
  try {
    const { sector } = req.query;
    let query = 'SELECT * FROM engine_oil_services WHERE 1=1';
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
    console.error('Error fetching engine oil services:', err);
    res.status(500).json({ message: 'Error fetching engine oil services' });
  }
});

// Create or update engine oil service
router.post('/', async (req, res) => {
  try {
    const {
      id,
      sector_code,
      vehicle_name,
      model,
      service_part_name,
      service_date,
      service_in_kms,
      service_in_hrs,
      next_service_date,
    } = req.body;

    if (!vehicle_name || !model || !service_part_name || !service_date) {
      return res.status(400).json({
        message: 'Vehicle name, model, service part name, and service date are required'
      });
    }

    if (id) {
      // Update existing record
      const result = await db.query(
        `UPDATE engine_oil_services SET
          sector_code = $1,
          vehicle_name = $2,
          model = $3,
          service_part_name = $4,
          service_date = $5,
          service_in_kms = $6,
          service_in_hrs = $7,
          next_service_date = $8,
          updated_at = CURRENT_TIMESTAMP
        WHERE id = $9
        RETURNING *`,
        [
          sector_code || null,
          vehicle_name,
          model,
          service_part_name,
          service_date,
          service_in_kms || null,
          service_in_hrs || null,
          next_service_date || null,
          id,
        ]
      );

      if (result.rows.length === 0) {
        return res.status(404).json({ message: 'Engine oil service not found' });
      }

      res.status(200).json(result.rows[0]);
    } else {
      // Create new record
      const result = await db.query(
        `INSERT INTO engine_oil_services (
          sector_code, vehicle_name, model, service_part_name,
          service_date, service_in_kms, service_in_hrs, next_service_date
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
        RETURNING *`,
        [
          sector_code || null,
          vehicle_name,
          model,
          service_part_name,
          service_date,
          service_in_kms || null,
          service_in_hrs || null,
          next_service_date || null,
        ]
      );

      res.status(201).json(result.rows[0]);
    }
  } catch (err) {
    console.error('Error saving engine oil service:', err);
    res.status(500).json({ message: err.message || 'Error saving engine oil service' });
  }
});

// Update engine oil service
router.put('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const {
      sector_code,
      vehicle_name,
      model,
      service_part_name,
      service_date,
      service_in_kms,
      service_in_hrs,
      next_service_date,
    } = req.body;

    if (!vehicle_name || !model || !service_part_name || !service_date) {
      return res.status(400).json({
        message: 'Vehicle name, model, service part name, and service date are required'
      });
    }

    const result = await db.query(
      `UPDATE engine_oil_services SET
        sector_code = $1,
        vehicle_name = $2,
        model = $3,
        service_part_name = $4,
        service_date = $5,
        service_in_kms = $6,
        service_in_hrs = $7,
        next_service_date = $8,
        updated_at = CURRENT_TIMESTAMP
      WHERE id = $9
      RETURNING *`,
      [
        sector_code || null,
        vehicle_name,
        model,
        service_part_name,
        service_date,
        service_in_kms || null,
        service_in_hrs || null,
        next_service_date || null,
        id,
      ]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ message: 'Engine oil service not found' });
    }

    res.status(200).json(result.rows[0]);
  } catch (err) {
    console.error('Error updating engine oil service:', err);
    res.status(500).json({ message: err.message || 'Error updating engine oil service' });
  }
});

// Delete engine oil service
router.delete('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const result = await db.query('DELETE FROM engine_oil_services WHERE id = $1 RETURNING *', [id]);

    if (result.rows.length === 0) {
      return res.status(404).json({ message: 'Engine oil service not found' });
    }

    res.status(204).send();
  } catch (err) {
    console.error('Error deleting engine oil service:', err);
    res.status(500).json({ message: 'Error deleting engine oil service' });
  }
});

export default router;

