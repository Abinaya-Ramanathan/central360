import { Router } from 'express';
import db from '../db.js';

const router = Router();

// Get item prices with item names (for Item Price tab), optionally by sector
router.get('/', async (req, res) => {
  try {
    const { sector } = req.query;

    // Ensure all stock items appear as item names (and have a default item_prices row)
    // 1) Sync stock_items -> item_names
    await db.query(`
      INSERT INTO item_names (item_name, sector_code, vehicle_type, part_number)
      SELECT si.item_name, si.sector_code, si.vehicle_type, si.part_number
      FROM stock_items si
      LEFT JOIN item_names iname
        ON iname.item_name = si.item_name
       AND iname.sector_code = si.sector_code
      WHERE iname.id IS NULL
    `);

    // 2) Ensure every item_name has an item_prices row
    await db.query(`
      INSERT INTO item_prices (item_name_id, quantity, unit, new_price, old_price)
      SELECT iname.id, '0', NULL, 0, 0
      FROM item_names iname
      LEFT JOIN item_prices ip
        ON ip.item_name_id = iname.id
      WHERE ip.id IS NULL
    `);

    let query = `
      SELECT iname.id as item_name_id, iname.item_name, iname.sector_code,
             ip.id as id, ip.quantity, ip.unit, ip.new_price, ip.old_price
      FROM item_names iname
      LEFT JOIN item_prices ip ON ip.item_name_id = iname.id
      WHERE 1=1
    `;
    const params = [];
    let paramCount = 1;
    if (sector) {
      query += ` AND iname.sector_code = $${paramCount++}`;
      params.push(sector);
    }
    query += ' ORDER BY iname.sector_code, iname.item_name';
    const { rows } = await db.query(query, params);
    res.json(rows);
  } catch (err) {
    console.error('Error fetching item prices:', err);
    res.status(500).json({ message: 'Error fetching item prices' });
  }
});

// Update one item price row (by item_name_id or id)
router.put('/', async (req, res) => {
  try {
    const { item_name_id, id, quantity, unit, new_price, old_price } = req.body;
    const priceId = id != null ? parseInt(id, 10) : null;
    const itemNameId = item_name_id != null ? parseInt(item_name_id, 10) : null;

    if (priceId != null && !isNaN(priceId)) {
      const result = await db.query(
        `UPDATE item_prices SET quantity = COALESCE($1, quantity), unit = $2,
         new_price = COALESCE($3, new_price), old_price = COALESCE($4, old_price),
         updated_at = CURRENT_TIMESTAMP WHERE id = $5 RETURNING *`,
        [quantity ?? '0', unit || null, new_price != null ? parseFloat(new_price) : null, old_price != null ? parseFloat(old_price) : null, priceId]
      );
      if (result.rows.length === 0) return res.status(404).json({ message: 'Item price not found' });
      return res.json(result.rows[0]);
    }

    if (itemNameId != null && !isNaN(itemNameId)) {
      const existing = await db.query('SELECT id FROM item_prices WHERE item_name_id = $1', [itemNameId]);
      const newPriceVal = new_price != null ? parseFloat(new_price) : 0;
      const oldPriceVal = old_price != null ? parseFloat(old_price) : 0;
      if (existing.rows.length > 0) {
        const result = await db.query(
          `UPDATE item_prices SET quantity = COALESCE($1, quantity), unit = $2,
           new_price = COALESCE($3, new_price), old_price = COALESCE($4, old_price),
           updated_at = CURRENT_TIMESTAMP WHERE item_name_id = $5 RETURNING *`,
          [quantity ?? '0', unit || null, newPriceVal, oldPriceVal, itemNameId]
        );
        return res.json(result.rows[0]);
      }
      const result = await db.query(
        'INSERT INTO item_prices (item_name_id, quantity, unit, new_price, old_price) VALUES ($1, $2, $3, $4, $5) RETURNING *',
        [itemNameId, quantity ?? '0', unit || null, newPriceVal, oldPriceVal]
      );
      return res.status(201).json(result.rows[0]);
    }

    return res.status(400).json({ message: 'id or item_name_id required' });
  } catch (err) {
    console.error('Error updating item price:', err);
    res.status(500).json({ message: 'Error updating item price' });
  }
});

export default router;
