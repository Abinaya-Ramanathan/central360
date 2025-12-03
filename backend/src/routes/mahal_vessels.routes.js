import { Router } from 'express';
import db from '../db.js';

const router = Router();

// Get all mahal vessels
router.get('/', async (req, res) => {
  try {
    const { mahal_detail } = req.query;
    let query = 'SELECT * FROM mahal_vessels WHERE 1=1';
    const params = [];
    let paramCount = 1;

    if (mahal_detail) {
      query += ` AND mahal_detail = $${paramCount++}`;
      params.push(mahal_detail);
    }

    query += ' ORDER BY mahal_detail, item_name, created_at DESC';
    const { rows } = await db.query(query, params);
    res.json(rows);
  } catch (err) {
    console.error('Error fetching mahal vessels:', err);
    res.status(500).json({ message: 'Error fetching mahal vessels' });
  }
});

// Create mahal vessel
router.post('/', async (req, res) => {
  try {
    const { mahal_detail, item_name, count } = req.body;

    if (!mahal_detail || !item_name || count === undefined) {
      return res.status(400).json({ 
        message: 'Mahal detail, item name, and count are required' 
      });
    }

    // Validate mahal_detail
    const validMahalDetails = ['Thanthondrimalai Mini hall', 'Thirukampuliyur Minihall', 'Thirukampuliyur Big Hall'];
    if (!validMahalDetails.includes(mahal_detail)) {
      return res.status(400).json({ 
        message: 'Invalid mahal detail. Must be one of: ' + validMahalDetails.join(', ') 
      });
    }

    const result = await db.query(
      `INSERT INTO mahal_vessels (mahal_detail, item_name, count)
       VALUES ($1, $2, $3)
       RETURNING *`,
      [mahal_detail, item_name, count || 1]
    );

    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error('Error creating mahal vessel:', err);
    res.status(500).json({
      message: 'Error creating mahal vessel',
      error: process.env.NODE_ENV === 'development' ? err.message : undefined
    });
  }
});

// Update mahal vessel
router.put('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { mahal_detail, item_name, count } = req.body;

    if (!mahal_detail || !item_name || count === undefined) {
      return res.status(400).json({ 
        message: 'Mahal detail, item name, and count are required' 
      });
    }

    // Validate mahal_detail
    const validMahalDetails = ['Thanthondrimalai Mini hall', 'Thirukampuliyur Minihall', 'Thirukampuliyur Big Hall'];
    if (!validMahalDetails.includes(mahal_detail)) {
      return res.status(400).json({ 
        message: 'Invalid mahal detail. Must be one of: ' + validMahalDetails.join(', ') 
      });
    }

    const result = await db.query(
      `UPDATE mahal_vessels 
       SET mahal_detail = $1, item_name = $2, count = $3, updated_at = CURRENT_TIMESTAMP
       WHERE id = $4
       RETURNING *`,
      [mahal_detail, item_name, count, id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ message: 'Mahal vessel not found' });
    }

    res.json(result.rows[0]);
  } catch (err) {
    console.error('Error updating mahal vessel:', err);
    res.status(500).json({
      message: 'Error updating mahal vessel',
      error: process.env.NODE_ENV === 'development' ? err.message : undefined
    });
  }
});

// Delete mahal vessel
router.delete('/:id', async (req, res) => {
  try {
    const { id } = req.params;

    const result = await db.query(
      'DELETE FROM mahal_vessels WHERE id = $1 RETURNING *',
      [id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ message: 'Mahal vessel not found' });
    }

    res.status(200).json({ message: 'Mahal vessel deleted successfully' });
  } catch (err) {
    console.error('Error deleting mahal vessel:', err);
    res.status(500).json({
      message: 'Error deleting mahal vessel',
      error: process.env.NODE_ENV === 'development' ? err.message : undefined
    });
  }
});

export default router;

