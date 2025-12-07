import { Router } from 'express';
import db from '../db.js';

const router = Router();

// Get all mining activities (optionally filtered by sector)
router.get('/', async (req, res) => {
  try {
    const { sector } = req.query;
    let query = 'SELECT * FROM mining_activities WHERE 1=1';
    const params = [];
    let paramCount = 1;

    if (sector) {
      query += ` AND sector_code = $${paramCount++}`;
      params.push(sector);
    }

    query += ' ORDER BY activity_name';
    const { rows } = await db.query(query, params);
    res.json(rows);
  } catch (err) {
    console.error('Error fetching mining activities:', err);
    res.status(500).json({ message: 'Error fetching mining activities' });
  }
});

// Create a new mining activity
router.post('/', async (req, res) => {
  try {
    const { activity_name, sector_code, description } = req.body;

    // Validation
    if (!activity_name || !activity_name.trim()) {
      return res.status(400).json({ message: 'Activity name is required' });
    }
    if (!sector_code) {
      return res.status(400).json({ message: 'Sector code is required' });
    }

    // Check if sector exists
    const sectorCheck = await db.query('SELECT code FROM sectors WHERE code = $1', [sector_code]);
    if (sectorCheck.rows.length === 0) {
      return res.status(404).json({ message: 'Sector not found' });
    }

    // Check if mining activity already exists for this sector
    const existingCheck = await db.query(
      'SELECT id FROM mining_activities WHERE activity_name = $1 AND sector_code = $2',
      [activity_name.trim(), sector_code]
    );
    if (existingCheck.rows.length > 0) {
      return res.status(400).json({ message: 'Mining activity already exists for this sector' });
    }

    const result = await db.query(
      'INSERT INTO mining_activities (activity_name, sector_code, description) VALUES ($1, $2, $3) RETURNING *',
      [activity_name.trim(), sector_code, description?.trim() || null]
    );

    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error('Error creating mining activity:', err);
    if (err.code === '23505') {
      return res.status(400).json({ message: 'Mining activity already exists for this sector' });
    }
    res.status(500).json({
      message: 'Error creating mining activity',
      error: process.env.NODE_ENV === 'development' ? err.message : undefined
    });
  }
});

// Update a mining activity
router.put('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { activity_name, sector_code, description } = req.body;

    if (!activity_name || !activity_name.trim()) {
      return res.status(400).json({ message: 'Activity name is required' });
    }
    if (!sector_code) {
      return res.status(400).json({ message: 'Sector code is required' });
    }

    // Check if sector exists
    const sectorCheck = await db.query('SELECT code FROM sectors WHERE code = $1', [sector_code]);
    if (sectorCheck.rows.length === 0) {
      return res.status(404).json({ message: 'Sector not found' });
    }

    // Check if mining activity name already exists for this sector (excluding current item)
    const existingCheck = await db.query(
      'SELECT id FROM mining_activities WHERE activity_name = $1 AND sector_code = $2 AND id != $3',
      [activity_name.trim(), sector_code, id]
    );
    if (existingCheck.rows.length > 0) {
      return res.status(400).json({ message: 'Mining activity already exists for this sector' });
    }

    const result = await db.query(
      'UPDATE mining_activities SET activity_name = $1, sector_code = $2, description = $3, updated_at = CURRENT_TIMESTAMP WHERE id = $4 RETURNING *',
      [activity_name.trim(), sector_code, description?.trim() || null, id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ message: 'Mining activity not found' });
    }

    res.json(result.rows[0]);
  } catch (err) {
    console.error('Error updating mining activity:', err);
    if (err.code === '23505') {
      return res.status(400).json({ message: 'Mining activity already exists for this sector' });
    }
    res.status(500).json({
      message: 'Error updating mining activity',
      error: process.env.NODE_ENV === 'development' ? err.message : undefined
    });
  }
});

// Delete a mining activity
router.delete('/:id', async (req, res) => {
  try {
    const { id } = req.params;

    const result = await db.query('DELETE FROM mining_activities WHERE id = $1 RETURNING *', [id]);

    if (result.rows.length === 0) {
      return res.status(404).json({ message: 'Mining activity not found' });
    }

    res.json({ message: 'Mining activity deleted successfully' });
  } catch (err) {
    console.error('Error deleting mining activity:', err);
    res.status(500).json({
      message: 'Error deleting mining activity',
      error: process.env.NODE_ENV === 'development' ? err.message : undefined
    });
  }
});

// Get daily mining activities (optionally filtered by date and sector)
router.get('/daily', async (req, res) => {
  try {
    const { date, sector } = req.query;
    let query = `
      SELECT 
        dma.*,
        ma.activity_name,
        ma.sector_code,
        ma.description
      FROM daily_mining_activities dma
      JOIN mining_activities ma ON dma.activity_id = ma.id
      WHERE 1=1
    `;
    const params = [];
    let paramCount = 1;

    if (date) {
      query += ` AND dma.date = $${paramCount++}::date`;
      params.push(date);
    }

    if (sector) {
      query += ` AND ma.sector_code = $${paramCount++}`;
      params.push(sector);
    }

    query += ' ORDER BY dma.date DESC, ma.activity_name';
    const { rows } = await db.query(query, params);
    res.json(rows);
  } catch (err) {
    console.error('Error fetching daily mining activities:', err);
    res.status(500).json({ message: 'Error fetching daily mining activities' });
  }
});

// Create or update daily mining activity
router.post('/daily', async (req, res) => {
  try {
    const { activity_id, date, quantity, unit, notes } = req.body;

    if (!activity_id) {
      return res.status(400).json({ message: 'Activity ID is required' });
    }
    if (!date) {
      return res.status(400).json({ message: 'Date is required' });
    }

    // Check if activity exists
    const activityCheck = await db.query('SELECT id FROM mining_activities WHERE id = $1', [activity_id]);
    if (activityCheck.rows.length === 0) {
      return res.status(404).json({ message: 'Mining activity not found' });
    }

    const result = await db.query(
      `INSERT INTO daily_mining_activities (activity_id, date, quantity, unit, notes)
       VALUES ($1, $2::date, $3, $4, $5)
       ON CONFLICT (activity_id, date)
       DO UPDATE SET 
         quantity = EXCLUDED.quantity,
         unit = EXCLUDED.unit,
         notes = EXCLUDED.notes,
         updated_at = CURRENT_TIMESTAMP
       RETURNING *`,
      [activity_id, date, quantity || 0, unit?.trim() || null, notes?.trim() || null]
    );

    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error('Error creating/updating daily mining activity:', err);
    res.status(500).json({
      message: 'Error creating/updating daily mining activity',
      error: process.env.NODE_ENV === 'development' ? err.message : undefined
    });
  }
});

// Delete daily mining activity
router.delete('/daily/:id', async (req, res) => {
  try {
    const { id } = req.params;

    const result = await db.query('DELETE FROM daily_mining_activities WHERE id = $1 RETURNING *', [id]);

    if (result.rows.length === 0) {
      return res.status(404).json({ message: 'Daily mining activity not found' });
    }

    res.json({ message: 'Daily mining activity deleted successfully' });
  } catch (err) {
    console.error('Error deleting daily mining activity:', err);
    res.status(500).json({
      message: 'Error deleting daily mining activity',
      error: process.env.NODE_ENV === 'development' ? err.message : undefined
    });
  }
});

export default router;

