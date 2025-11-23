import { Router } from 'express';
import db from '../db.js';

const router = Router();

// Get all products (optionally filtered by sector)
router.get('/', async (req, res) => {
  try {
    const { sector } = req.query;
    let query = 'SELECT * FROM products WHERE 1=1';
    const params = [];
    let paramCount = 1;

    if (sector) {
      query += ` AND sector_code = $${paramCount++}`;
      params.push(sector);
    }

    query += ' ORDER BY product_name';
    const { rows } = await db.query(query, params);
    res.json(rows);
  } catch (err) {
    console.error('Error fetching products:', err);
    res.status(500).json({ message: 'Error fetching products' });
  }
});

// Create a new product
router.post('/', async (req, res) => {
  try {
    const { product_name, sector_code } = req.body;

    // Validation
    if (!product_name || !product_name.trim()) {
      return res.status(400).json({ message: 'Product name is required' });
    }
    if (!sector_code) {
      return res.status(400).json({ message: 'Sector code is required' });
    }

    // Check if sector exists
    const sectorCheck = await db.query('SELECT code FROM sectors WHERE code = $1', [sector_code]);
    if (sectorCheck.rows.length === 0) {
      return res.status(404).json({ message: 'Sector not found' });
    }

    // Check if product already exists for this sector
    const existingCheck = await db.query(
      'SELECT id FROM products WHERE product_name = $1 AND sector_code = $2',
      [product_name.trim(), sector_code]
    );
    if (existingCheck.rows.length > 0) {
      return res.status(400).json({ message: 'Product already exists for this sector' });
    }

    const result = await db.query(
      'INSERT INTO products (product_name, sector_code) VALUES ($1, $2) RETURNING *',
      [product_name.trim(), sector_code]
    );

    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error('Error creating product:', err);
    if (err.code === '23505') {
      // Unique constraint violation
      return res.status(400).json({ message: 'Product already exists for this sector' });
    }
    res.status(500).json({
      message: 'Error creating product',
      error: process.env.NODE_ENV === 'development' ? err.message : undefined
    });
  }
});

// Update a product
router.put('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { product_name, sector_code } = req.body;

    if (!product_name || !product_name.trim()) {
      return res.status(400).json({ message: 'Product name is required' });
    }
    if (!sector_code) {
      return res.status(400).json({ message: 'Sector code is required' });
    }

    // Check if sector exists
    const sectorCheck = await db.query('SELECT code FROM sectors WHERE code = $1', [sector_code]);
    if (sectorCheck.rows.length === 0) {
      return res.status(404).json({ message: 'Sector not found' });
    }

    // Check if product name already exists for this sector (excluding current product)
    const existingCheck = await db.query(
      'SELECT id FROM products WHERE product_name = $1 AND sector_code = $2 AND id != $3',
      [product_name.trim(), sector_code, id]
    );
    if (existingCheck.rows.length > 0) {
      return res.status(400).json({ message: 'Product already exists for this sector' });
    }

    const result = await db.query(
      'UPDATE products SET product_name = $1, sector_code = $2, updated_at = CURRENT_TIMESTAMP WHERE id = $3 RETURNING *',
      [product_name.trim(), sector_code, id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ message: 'Product not found' });
    }

    res.json(result.rows[0]);
  } catch (err) {
    console.error('Error updating product:', err);
    if (err.code === '23505') {
      return res.status(400).json({ message: 'Product already exists for this sector' });
    }
    res.status(500).json({
      message: 'Error updating product',
      error: process.env.NODE_ENV === 'development' ? err.message : undefined
    });
  }
});

// Delete a product
router.delete('/:id', async (req, res) => {
  try {
    const { id } = req.params;

    const result = await db.query('DELETE FROM products WHERE id = $1 RETURNING *', [id]);

    if (result.rows.length === 0) {
      return res.status(404).json({ message: 'Product not found' });
    }

    res.status(200).json({ message: 'Product deleted successfully' });
  } catch (err) {
    console.error('Error deleting product:', err);
    res.status(500).json({
      message: 'Error deleting product',
      error: process.env.NODE_ENV === 'development' ? err.message : undefined
    });
  }
});

export default router;

