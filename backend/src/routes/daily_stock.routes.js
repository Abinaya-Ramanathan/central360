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

      // Get total daily stock taken for each unit type
      const dailyStockQuery = await db.query(
        `SELECT 
          COALESCE(SUM(CASE WHEN unit = 'gram' THEN 
            CASE WHEN quantity_taken LIKE '%/%' THEN
              CAST(SPLIT_PART(quantity_taken, '/', 1) AS DECIMAL) / NULLIF(CAST(SPLIT_PART(quantity_taken, '/', 2) AS DECIMAL), 0)
            ELSE CAST(quantity_taken AS DECIMAL) END
          ELSE 0 END), 0) as total_gram,
          COALESCE(SUM(CASE WHEN unit = 'kg' THEN 
            CASE WHEN quantity_taken LIKE '%/%' THEN
              CAST(SPLIT_PART(quantity_taken, '/', 1) AS DECIMAL) / NULLIF(CAST(SPLIT_PART(quantity_taken, '/', 2) AS DECIMAL), 0)
            ELSE CAST(quantity_taken AS DECIMAL) END
          ELSE 0 END), 0) as total_kg,
          COALESCE(SUM(CASE WHEN unit = 'Litre' THEN 
            CASE WHEN quantity_taken LIKE '%/%' THEN
              CAST(SPLIT_PART(quantity_taken, '/', 1) AS DECIMAL) / NULLIF(CAST(SPLIT_PART(quantity_taken, '/', 2) AS DECIMAL), 0)
            ELSE CAST(quantity_taken AS DECIMAL) END
          ELSE 0 END), 0) as total_litre,
          COALESCE(SUM(CASE WHEN unit = 'pieces' THEN 
            CASE WHEN quantity_taken LIKE '%/%' THEN
              CAST(SPLIT_PART(quantity_taken, '/', 1) AS DECIMAL) / NULLIF(CAST(SPLIT_PART(quantity_taken, '/', 2) AS DECIMAL), 0)
            ELSE CAST(quantity_taken AS DECIMAL) END
          ELSE 0 END), 0) as total_pieces,
          COALESCE(SUM(CASE WHEN unit = 'Boxes' THEN 
            CASE WHEN quantity_taken LIKE '%/%' THEN
              CAST(SPLIT_PART(quantity_taken, '/', 1) AS DECIMAL) / NULLIF(CAST(SPLIT_PART(quantity_taken, '/', 2) AS DECIMAL), 0)
            ELSE CAST(quantity_taken AS DECIMAL) END
          ELSE 0 END), 0) as total_boxes
        FROM daily_stock 
        WHERE item_id = $1`,
        [itemId]
      );

      const totalTakenGram = parseNumeric(dailyStockQuery.rows[0]?.total_gram || '0');
      const totalTakenKg = parseNumeric(dailyStockQuery.rows[0]?.total_kg || '0');
      const totalTakenLitre = parseNumeric(dailyStockQuery.rows[0]?.total_litre || '0');
      const totalTakenPieces = parseNumeric(dailyStockQuery.rows[0]?.total_pieces || '0');
      const totalTakenBoxes = parseNumeric(dailyStockQuery.rows[0]?.total_boxes || '0');

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
      const { id, item_id, quantity_taken, unit, reason } = update;

      if (!item_id) {
        continue;
      }

      // Parse numeric value (accepts both string and number)
      const quantityTaken = parseNumeric(quantity_taken);

      // Get the date from query or use current date
      const { date } = req.query;
      const stockDate = date || new Date().toISOString().split('T')[0];

      if (id) {
        // Update existing record
        const existing = await db.query('SELECT * FROM daily_stock WHERE id = $1', [id]);
        if (existing.rows.length > 0) {
          const result = await db.query(
            'UPDATE daily_stock SET quantity_taken = $1, unit = $2, reason = $3, updated_at = CURRENT_TIMESTAMP WHERE id = $4 RETURNING *',
            [quantityTaken, unit || null, reason || '', id]
          );
          results.push(result.rows[0]);
          
          // Recalculate remaining stock in overall_stock after updating daily stock
          const updateItemId = existing.rows[0].item_id;
          await recalculateOverallStock(updateItemId);
        }
      } else {
        // Create new record - check if one exists for this item and date
        const existing = await db.query(
          'SELECT * FROM daily_stock WHERE item_id = $1 AND stock_date = $2',
          [item_id, stockDate]
        );
        
        if (existing.rows.length > 0) {
          // Update existing record
          const result = await db.query(
            'UPDATE daily_stock SET quantity_taken = $1, unit = $2, reason = $3, updated_at = CURRENT_TIMESTAMP WHERE id = $4 RETURNING *',
            [quantityTaken, unit || null, reason || '', existing.rows[0].id]
          );
          results.push(result.rows[0]);
          
          // Recalculate remaining stock in overall_stock after updating daily stock
          await recalculateOverallStock(item_id);
        } else {
          // Create new record
          const result = await db.query(
            'INSERT INTO daily_stock (item_id, quantity_taken, unit, reason, stock_date) VALUES ($1, $2, $3, $4, $5) RETURNING *',
            [item_id, quantityTaken, unit || null, reason || '', stockDate]
          );
          results.push(result.rows[0]);
          
          // Recalculate remaining stock in overall_stock after saving daily stock
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

