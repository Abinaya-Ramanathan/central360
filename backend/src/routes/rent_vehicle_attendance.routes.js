import { Router } from 'express';
import db from '../db.js';

const router = Router();

// Get rent vehicle attendance records
router.get('/', async (req, res) => {
  try {
    const { sector, month, date } = req.query;
    let query = 'SELECT id, vehicle_id, vehicle_name, sector_code, date, status FROM rent_vehicle_attendance WHERE 1=1';
    const params = [];
    let paramCount = 1;

    if (sector) {
      query += ` AND sector_code = $${paramCount++}`;
      params.push(sector);
    }
    if (month) {
      query += ` AND EXTRACT(MONTH FROM date) = $${paramCount++}`;
      params.push(month);
    }
    if (date) {
      query += ` AND date::date = $${paramCount++}::date`;
      params.push(date);
    }

    query += ' ORDER BY date DESC, vehicle_name';
    const { rows } = await db.query(query, params);
    res.json(rows);
  } catch (err) {
    console.error('Error fetching rent vehicle attendance:', err);
    res.status(500).json({ message: 'Error fetching rent vehicle attendance' });
  }
});

// Create or update rent vehicle attendance
router.post('/', async (req, res) => {
  try {
    const {
      vehicle_id,
      vehicle_name,
      sector_code,
      date,
      status,
    } = req.body;

    // Check if attendance record already exists
    const existing = await db.query(
      'SELECT * FROM rent_vehicle_attendance WHERE vehicle_id = $1 AND date = $2',
      [vehicle_id, date]
    );

    if (existing.rows.length > 0) {
      // Update existing record
      const { rows } = await db.query(
        `UPDATE rent_vehicle_attendance SET
          status = $1, updated_at = CURRENT_TIMESTAMP
        WHERE vehicle_id = $2 AND date = $3
        RETURNING *`,
        [status, vehicle_id, date]
      );
      res.json(rows[0]);
    } else {
      // Create new record
      const { rows } = await db.query(
        `INSERT INTO rent_vehicle_attendance (
          vehicle_id, vehicle_name, sector_code, date, status
        ) VALUES ($1, $2, $3, $4, $5)
        RETURNING *`,
        [
          vehicle_id,
          vehicle_name,
          sector_code,
          date,
          status || null,
        ]
      );
      res.status(201).json(rows[0]);
    }
  } catch (err) {
    console.error('Error saving rent vehicle attendance:', err);
    res.status(500).json({
      message: 'Error saving rent vehicle attendance',
      error: process.env.NODE_ENV === 'development' ? err.message : undefined
    });
  }
});

// Bulk save rent vehicle attendance
router.post('/bulk', async (req, res) => {
  try {
    const { records } = req.body;

    if (!Array.isArray(records) || records.length === 0) {
      return res.status(400).json({ message: 'Records array is required' });
    }

    const results = [];
    for (const record of records) {
      const {
        vehicle_id,
        vehicle_name,
        sector_code,
        date,
        status,
      } = record;

      // Check if attendance record already exists
      const existing = await db.query(
        'SELECT * FROM rent_vehicle_attendance WHERE vehicle_id = $1 AND date = $2',
        [vehicle_id, date]
      );

      if (existing.rows.length > 0) {
        // Update existing record
        const { rows } = await db.query(
          `UPDATE rent_vehicle_attendance SET
            status = $1, updated_at = CURRENT_TIMESTAMP
          WHERE vehicle_id = $2 AND date = $3
          RETURNING *`,
          [status, vehicle_id, date]
        );
        results.push(rows[0]);
      } else {
        // Create new record
        const { rows } = await db.query(
          `INSERT INTO rent_vehicle_attendance (
            vehicle_id, vehicle_name, sector_code, date, status
          ) VALUES ($1, $2, $3, $4, $5)
          RETURNING *`,
          [
            vehicle_id,
            vehicle_name,
            sector_code,
            date,
            status || null,
          ]
        );
        results.push(rows[0]);
      }
    }

    res.status(201).json(results);
  } catch (err) {
    console.error('Error bulk saving rent vehicle attendance:', err);
    res.status(500).json({
      message: 'Error bulk saving rent vehicle attendance',
      error: process.env.NODE_ENV === 'development' ? err.message : undefined
    });
  }
});

export default router;

