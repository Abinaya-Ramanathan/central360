import { Router } from 'express';
import db from '../db.js';

const router = Router();

// Get all stock items (optionally filtered by sector)
router.get('/', async (req, res) => {
  try {
    const { sector } = req.query;
    let query = 'SELECT * FROM stock_items WHERE 1=1';
    const params = [];
    let paramCount = 1;

    if (sector) {
      query += ` AND sector_code = $${paramCount++}`;
      params.push(sector);
    }

    query += ' ORDER BY item_name';
    const { rows } = await db.query(query, params);
    res.json(rows);
  } catch (err) {
    console.error('Error fetching stock items:', err);
    res.status(500).json({ message: 'Error fetching stock items' });
  }
});

// Create a new stock item
router.post('/', async (req, res) => {
  try {
    const { item_name, sector_code, vehicle_type, part_number } = req.body;

    // Validation
    if (!item_name || !item_name.trim()) {
      return res.status(400).json({ message: 'Item name is required' });
    }
    if (!sector_code) {
      return res.status(400).json({ message: 'Sector code is required' });
    }

    // Check if sector exists
    const sectorCheck = await db.query('SELECT code FROM sectors WHERE code = $1', [sector_code]);
    if (sectorCheck.rows.length === 0) {
      return res.status(404).json({ message: 'Sector not found' });
    }

    // Check if stock item already exists for this sector
    const existingCheck = await db.query(
      'SELECT id FROM stock_items WHERE item_name = $1 AND sector_code = $2',
      [item_name.trim(), sector_code]
    );
    if (existingCheck.rows.length > 0) {
      return res.status(400).json({ message: 'Stock item already exists for this sector' });
    }

    const result = await db.query(
      'INSERT INTO stock_items (item_name, sector_code, vehicle_type, part_number) VALUES ($1, $2, $3, $4) RETURNING *',
      [item_name.trim(), sector_code, vehicle_type?.trim() || null, part_number?.trim() || null]
    );

    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error('Error creating stock item:', err);
    if (err.code === '23505') {
      return res.status(400).json({ message: 'Stock item already exists for this sector' });
    }
    res.status(500).json({
      message: 'Error creating stock item',
      error: process.env.NODE_ENV === 'development' ? err.message : undefined
    });
  }
});

// Update a stock item
router.put('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { item_name, sector_code, vehicle_type, part_number } = req.body;

    if (!item_name || !item_name.trim()) {
      return res.status(400).json({ message: 'Item name is required' });
    }
    if (!sector_code) {
      return res.status(400).json({ message: 'Sector code is required' });
    }

    // Check if sector exists
    const sectorCheck = await db.query('SELECT code FROM sectors WHERE code = $1', [sector_code]);
    if (sectorCheck.rows.length === 0) {
      return res.status(404).json({ message: 'Sector not found' });
    }

    // Check if stock item name already exists for this sector (excluding current item)
    const existingCheck = await db.query(
      'SELECT id FROM stock_items WHERE item_name = $1 AND sector_code = $2 AND id != $3',
      [item_name.trim(), sector_code, id]
    );
    if (existingCheck.rows.length > 0) {
      return res.status(400).json({ message: 'Stock item already exists for this sector' });
    }

    const result = await db.query(
      'UPDATE stock_items SET item_name = $1, sector_code = $2, vehicle_type = $4, part_number = $5, updated_at = CURRENT_TIMESTAMP WHERE id = $3 RETURNING *',
      [item_name.trim(), sector_code, id, vehicle_type?.trim() || null, part_number?.trim() || null]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ message: 'Stock item not found' });
    }

    res.json(result.rows[0]);
  } catch (err) {
    console.error('Error updating stock item:', err);
    if (err.code === '23505') {
      return res.status(400).json({ message: 'Stock item already exists for this sector' });
    }
    res.status(500).json({
      message: 'Error updating stock item',
      error: process.env.NODE_ENV === 'development' ? err.message : undefined
    });
  }
});

// Delete a stock item
router.delete('/:id', async (req, res) => {
  try {
    const { id } = req.params;

    const result = await db.query('DELETE FROM stock_items WHERE id = $1 RETURNING *', [id]);

    if (result.rows.length === 0) {
      return res.status(404).json({ message: 'Stock item not found' });
    }

    res.status(200).json({ message: 'Stock item deleted successfully' });
  } catch (err) {
    console.error('Error deleting stock item:', err);
    res.status(500).json({
      message: 'Error deleting stock item',
      error: process.env.NODE_ENV === 'development' ? err.message : undefined
    });
  }
});

export default router;

