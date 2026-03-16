import { Router } from 'express';
import db from '../db.js';

const router = Router();

// Get all item names (optionally filtered by sector)
router.get('/', async (req, res) => {
  try {
    const { sector } = req.query;
    let query = 'SELECT * FROM item_names WHERE 1=1';
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
    console.error('Error fetching item names:', err);
    res.status(500).json({ message: 'Error fetching item names' });
  }
});

// Create item name
router.post('/', async (req, res) => {
  try {
    const { item_name, sector_code, vehicle_type, part_number } = req.body;
    if (!item_name || !item_name.trim()) {
      return res.status(400).json({ message: 'Item name is required' });
    }
    if (!sector_code) {
      return res.status(400).json({ message: 'Sector code is required' });
    }
    const sectorCheck = await db.query('SELECT code FROM sectors WHERE code = $1', [sector_code]);
    if (sectorCheck.rows.length === 0) {
      return res.status(404).json({ message: 'Sector not found' });
    }
    const result = await db.query(
      'INSERT INTO item_names (item_name, sector_code, vehicle_type, part_number) VALUES ($1, $2, $3, $4) RETURNING *',
      [item_name.trim(), sector_code, vehicle_type && vehicle_type.trim() ? vehicle_type.trim() : null, part_number && part_number.trim() ? part_number.trim() : null]
    );
    // Create a default item_prices row for this item
    await db.query(
      'INSERT INTO item_prices (item_name_id, quantity, unit, new_price, old_price) VALUES ($1, $2, $3, $4, $5)',
      [result.rows[0].id, '0', null, 0, 0]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error('Error creating item name:', err);
    if (err.code === '23505') {
      return res.status(400).json({ message: 'Item name already exists for this sector' });
    }
    res.status(500).json({ message: 'Error creating item name' });
  }
});

// Update item name
router.put('/:id', async (req, res) => {
  try {
    const id = parseInt(req.params.id, 10);
    const { item_name, sector_code, vehicle_type, part_number } = req.body;
    if (isNaN(id)) return res.status(400).json({ message: 'Invalid id' });
    if (!item_name || !item_name.trim()) {
      return res.status(400).json({ message: 'Item name is required' });
    }
    const result = await db.query(
      'UPDATE item_names SET item_name = $1, sector_code = COALESCE($2, sector_code), vehicle_type = $3, part_number = $4, updated_at = CURRENT_TIMESTAMP WHERE id = $5 RETURNING *',
      [item_name.trim(), sector_code || null, vehicle_type != null && String(vehicle_type).trim() ? String(vehicle_type).trim() : null, part_number != null && String(part_number).trim() ? String(part_number).trim() : null, id]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ message: 'Item name not found' });
    }
    res.json(result.rows[0]);
  } catch (err) {
    console.error('Error updating item name:', err);
    res.status(500).json({ message: 'Error updating item name' });
  }
});

// Delete item name (cascades to item_prices)
router.delete('/:id', async (req, res) => {
  try {
    const id = parseInt(req.params.id, 10);
    if (isNaN(id)) return res.status(400).json({ message: 'Invalid id' });
    const result = await db.query('DELETE FROM item_names WHERE id = $1 RETURNING id', [id]);
    if (result.rows.length === 0) {
      return res.status(404).json({ message: 'Item name not found' });
    }
    res.json({ message: 'Deleted' });
  } catch (err) {
    console.error('Error deleting item name:', err);
    res.status(500).json({ message: 'Error deleting item name' });
  }
});

export default router;
