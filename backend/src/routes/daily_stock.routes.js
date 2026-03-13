import { Router } from 'express';
import db from '../db.js';

const router = Router();

// Get daily stock records
router.get('/', async (req, res) => {
  try {
    const { month, date, sector } = req.query;
    let query = `
      SELECT ds.*, si.item_name, si.sector_code, si.vehicle_type, si.part_number, s.name as sector_name
      FROM daily_stock ds
      JOIN stock_items si ON ds.item_id = si.id
      JOIN sectors s ON si.sector_code = s.code
      WHERE 1=1
    `;
    const params = [];
    let paramCount = 1;

    if (month) {
      query += ` AND EXTRACT(MONTH FROM ds.stock_date) = $${paramCount++}`;
      params.push(parseInt(month));
    }
    if (date) {
      query += ` AND ds.stock_date = $${paramCount++}`;
      params.push(date);
    }
    if (sector) {
      query += ` AND si.sector_code = $${paramCount++}`;
      params.push(sector);
    }

    query += ' ORDER BY si.sector_code, si.item_name, ds.stock_date';
    const { rows } = await db.query(query, params);
    res.json(rows);
  } catch (err) {
    console.error('Error fetching daily stock:', err);
    res.status(500).json({ message: 'Error fetching daily stock' });
  }
});

// Helper: add parsed quantity for a given unit into totals object
function addToTotals(totals, qtyStr, unit) {
  const val = parseNumeric(qtyStr);
  if (!unit || val === 0) return;
  const u = String(unit).trim();
  if (u === 'gram') totals.gram += val;
  else if (u === 'kg') totals.kg += val;
  else if (u === 'Litre') totals.litre += val;
  else if (u === 'pieces') totals.pieces += val;
  else if (u === 'Boxes') totals.boxes += val;
}

// Helper function to recalculate overall stock remaining quantities
async function recalculateOverallStock(itemId) {
  try {
    const newStockQuery = await db.query(
      'SELECT new_stock_gram, new_stock_kg, new_stock_litre, new_stock_pieces, new_stock_boxes FROM overall_stock WHERE item_id = $1',
      [itemId]
    );

    if (newStockQuery.rows.length > 0) {
      const newGram = parseNumeric(newStockQuery.rows[0].new_stock_gram);
      const newKg = parseNumeric(newStockQuery.rows[0].new_stock_kg);
      const newLitre = parseNumeric(newStockQuery.rows[0].new_stock_litre);

      // Get all daily_stock rows for this item; sum quantity_taken + quantity_taken_main_branch + quantity_taken_thanthondrimalai by unit
      const dailyStockRows = await db.query(
        'SELECT quantity_taken, unit, quantity_taken_main_branch, unit_main_branch, quantity_taken_thanthondrimalai, unit_thanthondrimalai FROM daily_stock WHERE item_id = $1',
        [itemId]
      );
      const totals = { gram: 0, kg: 0, litre: 0, pieces: 0, boxes: 0 };
      for (const row of dailyStockRows.rows) {
        addToTotals(totals, row.quantity_taken, row.unit);
        addToTotals(totals, row.quantity_taken_main_branch, row.unit_main_branch);
        addToTotals(totals, row.quantity_taken_thanthondrimalai, row.unit_thanthondrimalai);
      }

      const totalTakenGram = totals.gram;
      const totalTakenKg = totals.kg;
      const totalTakenLitre = totals.litre;
      const totalTakenPieces = totals.pieces;
      const totalTakenBoxes = totals.boxes;

      // Convert everything to grams for unified calculation
      // 1 litre = 1000 gram, 1 kg = 1000 gram
      const newStockInGram = newGram + (newKg * 1000) + (newLitre * 1000);
      const totalTakenInGram = totalTakenGram + (totalTakenKg * 1000) + (totalTakenLitre * 1000);
      
      // Calculate total remaining in grams
      let totalRemainingInGram = Math.max(0, newStockInGram - totalTakenInGram);
      
      // Convert to different units for display
      const remainingKg = totalRemainingInGram / 1000;
      const remainingLitre = totalRemainingInGram / 1000;
      
      // Calculate remaining pieces separately (pieces don't convert to gram/kg/litre)
      const newPieces = parseNumeric(newStockQuery.rows[0].new_stock_pieces);
      const remainingPieces = Math.max(0, newPieces - totalTakenPieces);
      
      // Calculate remaining boxes separately (boxes don't convert to gram/kg/litre/pieces)
      const newBoxes = parseNumeric(newStockQuery.rows[0].new_stock_boxes);
      const remainingBoxes = Math.max(0, newBoxes - totalTakenBoxes);

      // Update remaining stock
      await db.query(
        `UPDATE overall_stock 
         SET remaining_stock_gram = $1, 
             remaining_stock_kg = $2, 
             remaining_stock_litre = $3,
             remaining_stock_pieces = $4,
             remaining_stock_boxes = $5,
             updated_at = CURRENT_TIMESTAMP
         WHERE item_id = $6`,
        [totalRemainingInGram, remainingKg, remainingLitre, remainingPieces, remainingBoxes, itemId]
      );
    }
  } catch (recalcError) {
    // Log error but don't fail the daily stock save
    console.error('Error recalculating remaining stock:', recalcError);
  }
}

// Helper function to parse numeric values (accepts both string and number)
function parseNumeric(value) {
  if (value === null || value === undefined || value === '') {
    return 0;
  }
  if (typeof value === 'number') {
    return parseFloat(value); // Keep as float for decimal support
  }
  if (typeof value === 'string') {
    // Trim whitespace
    const trimmed = value.trim();
    
    // Check if it's a fraction (e.g., "1/2", "3/4")
    if (trimmed.includes('/')) {
      const parts = trimmed.split('/');
      if (parts.length === 2) {
        const numerator = parseFloat(parts[0].trim());
        const denominator = parseFloat(parts[1].trim());
        if (!isNaN(numerator) && !isNaN(denominator) && denominator !== 0) {
          return numerator / denominator;
        }
      }
    }
    
    // Try parsing as regular number (decimal supported)
    const parsed = parseFloat(trimmed);
    return isNaN(parsed) ? 0 : parsed;
  }
  return 0;
}

// Update daily stock records
router.put('/', async (req, res) => {
  try {
    const { updates } = req.body;
    const { date } = req.query;

    if (!Array.isArray(updates)) {
      return res.status(400).json({ message: 'Updates must be an array' });
    }

    const results = [];
    for (const update of updates) {
      const {
        id,
        item_id,
        quantity_taken,
        unit,
        reason,
        quantity_taken_main_branch,
        unit_main_branch,
        quantity_taken_thanthondrimalai,
        unit_thanthondrimalai,
      } = update;

      if (!item_id) {
        continue;
      }

      const quantityTaken = String(quantity_taken ?? '0').trim();
      const qtyMain = quantity_taken_main_branch != null ? String(quantity_taken_main_branch).trim() : null;
      const qtyThanth = quantity_taken_thanthondrimalai != null ? String(quantity_taken_thanthondrimalai).trim() : null;

      const stockDate = date || new Date().toISOString().split('T')[0];

      if (id) {
        const existing = await db.query('SELECT * FROM daily_stock WHERE id = $1', [id]);
        if (existing.rows.length > 0) {
          const result = await db.query(
            `UPDATE daily_stock SET quantity_taken = $1, unit = $2, reason = $3,
             quantity_taken_main_branch = COALESCE($4, quantity_taken_main_branch),
             unit_main_branch = $5,
             quantity_taken_thanthondrimalai = COALESCE($6, quantity_taken_thanthondrimalai),
             unit_thanthondrimalai = $7,
             updated_at = CURRENT_TIMESTAMP WHERE id = $8 RETURNING *`,
            [quantityTaken, unit || null, reason || '', qtyMain, unit_main_branch || null, qtyThanth, unit_thanthondrimalai || null, id]
          );
          results.push(result.rows[0]);
          await recalculateOverallStock(existing.rows[0].item_id);
        }
      } else {
        const existing = await db.query(
          'SELECT * FROM daily_stock WHERE item_id = $1 AND stock_date = $2',
          [item_id, stockDate]
        );
        if (existing.rows.length > 0) {
          const result = await db.query(
            `UPDATE daily_stock SET quantity_taken = $1, unit = $2, reason = $3,
             quantity_taken_main_branch = COALESCE($4, quantity_taken_main_branch),
             unit_main_branch = $5,
             quantity_taken_thanthondrimalai = COALESCE($6, quantity_taken_thanthondrimalai),
             unit_thanthondrimalai = $7,
             updated_at = CURRENT_TIMESTAMP WHERE id = $8 RETURNING *`,
            [quantityTaken, unit || null, reason || '', qtyMain, unit_main_branch || null, qtyThanth, unit_thanthondrimalai || null, existing.rows[0].id]
          );
          results.push(result.rows[0]);
          await recalculateOverallStock(item_id);
        } else {
          const result = await db.query(
            `INSERT INTO daily_stock (item_id, quantity_taken, unit, reason, stock_date, quantity_taken_main_branch, unit_main_branch, quantity_taken_thanthondrimalai, unit_thanthondrimalai)
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9) RETURNING *`,
            [item_id, quantityTaken, unit || null, reason || '', stockDate, qtyMain, unit_main_branch || null, qtyThanth, unit_thanthondrimalai || null]
          );
          results.push(result.rows[0]);
          await recalculateOverallStock(item_id);
        }
      }
    }

    res.json(results);
  } catch (err) {
    console.error('Error updating daily stock:', err);
    res.status(500).json({
      message: 'Error updating daily stock',
      error: process.env.NODE_ENV === 'development' ? err.message : undefined
    });
  }
});

export default router;

