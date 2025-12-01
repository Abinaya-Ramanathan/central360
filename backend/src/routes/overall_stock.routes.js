import { Router } from 'express';
import db from '../db.js';

const router = Router();

// Get overall stock records
router.get('/', async (req, res) => {
  try {
    const { sector } = req.query;
    const params = [];
    let paramCount = 1;

    // Build the daily_stock join condition (no date/month filtering for overall stock)
    let dailyStockJoinCondition = 'os.item_id = ds.item_id';

    let query = `
      SELECT 
        os.*, 
        si.item_name, 
        si.sector_code, 
        si.vehicle_type, 
        si.part_number, 
        s.name as sector_name,
        COALESCE(SUM(
          CASE 
            WHEN ds.quantity_taken LIKE '%/%' THEN
              CAST(SPLIT_PART(ds.quantity_taken, '/', 1) AS DECIMAL) / NULLIF(CAST(SPLIT_PART(ds.quantity_taken, '/', 2) AS DECIMAL), 0)
            ELSE
              CAST(ds.quantity_taken AS DECIMAL)
          END
        ), 0) as total_taken
      FROM overall_stock os
      JOIN stock_items si ON os.item_id = si.id
      JOIN sectors s ON si.sector_code = s.code
      LEFT JOIN daily_stock ds ON ${dailyStockJoinCondition}
      WHERE 1=1
    `;

    if (sector) {
      query += ` AND si.sector_code = $${paramCount++}`;
      params.push(sector);
    }

    // Include all overall_stock columns in GROUP BY
    query += ` GROUP BY os.id, os.item_id, os.remaining_stock, os.new_stock, os.unit, 
      os.remaining_stock_gram, os.remaining_stock_kg, os.remaining_stock_litre, os.remaining_stock_pieces, os.remaining_stock_boxes,
      os.new_stock_gram, os.new_stock_kg, os.new_stock_litre, os.new_stock_pieces, os.new_stock_boxes,
      os.created_at, os.updated_at, os.new_stock_date,
      si.id, si.item_name, si.sector_code, si.vehicle_type, si.part_number, 
      s.code, s.name 
      ORDER BY si.sector_code, si.item_name`;
    const { rows } = await db.query(query, params);
    
    // Format the response - convert numeric values to strings for consistent display
    const processedRows = rows.map(row => {
      // Format decimal values to show proper decimals (e.g., 4.75 instead of 4.750000)
      const formatDecimal = (value) => {
        if (value === null || value === undefined || value === 0) return '0';
        const num = parseFloat(value);
        if (isNaN(num)) return '0';
        // Remove trailing zeros after decimal point, show up to 2 decimals
        return num.toFixed(2).replace(/\.?0+$/, '');
      };
      
      return {
        ...row,
        // Convert unit-specific columns to strings, defaulting to '0' if null/undefined
        remaining_stock_gram: (row.remaining_stock_gram ?? 0).toString(),
        remaining_stock_kg: formatDecimal(row.remaining_stock_kg), // Format kg with decimals
        remaining_stock_litre: formatDecimal(row.remaining_stock_litre),
        remaining_stock_pieces: (row.remaining_stock_pieces ?? 0).toString(),
        remaining_stock_boxes: (row.remaining_stock_boxes ?? 0).toString(),
        new_stock_gram: (row.new_stock_gram ?? 0).toString(),
        new_stock_kg: (row.new_stock_kg ?? 0).toString(),
        new_stock_litre: formatDecimal(row.new_stock_litre),
        new_stock_pieces: (row.new_stock_pieces ?? 0).toString(),
        new_stock_boxes: (row.new_stock_boxes ?? 0).toString(),
      };
    });
    
    res.json(processedRows);
  } catch (err) {
    console.error('Error fetching overall stock:', err);
    res.status(500).json({ message: 'Error fetching overall stock' });
  }
});

// Helper function to parse numeric values (accepts both string and number, including fractions)
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
    
    // Try parsing as regular number
    const parsed = parseFloat(trimmed);
    return isNaN(parsed) ? 0 : parsed;
  }
  return 0;
}

// Update overall stock records
router.put('/', async (req, res) => {
  try {
    const { updates } = req.body;

    if (!Array.isArray(updates)) {
      return res.status(400).json({ message: 'Updates must be an array' });
    }

    const results = [];
    for (const update of updates) {
      const { 
        id, 
        item_id, 
        remaining_stock_gram,
        remaining_stock_kg,
        remaining_stock_litre,
        remaining_stock_pieces,
        remaining_stock_boxes,
        new_stock_gram,
        new_stock_kg,
        new_stock_litre,
        new_stock_pieces,
        new_stock_boxes,
      } = update;

      // Get item_id - either from update or from existing record
      let finalItemId = item_id;
      if (!finalItemId && id) {
        // If we have id but no item_id, get item_id from existing record
        const existing = await db.query('SELECT item_id FROM overall_stock WHERE id = $1', [id]);
        if (existing.rows.length > 0) {
          finalItemId = existing.rows[0].item_id;
        }
      }

      if (!finalItemId) {
        continue; // Skip if we can't determine item_id
      }

      // Parse numeric values for new stock columns
      // Empty strings or null values will be parsed as 0
      // You can fill just one column (e.g., only litre) or multiple columns
      const newGram = parseNumeric(new_stock_gram || '');
      const newKg = parseNumeric(new_stock_kg || '');
      const newLitre = parseNumeric(new_stock_litre || '');
      const newPieces = parseNumeric(new_stock_pieces || '');
      const newBoxes = parseNumeric(new_stock_boxes || '');
      
      // If all new stock values are 0 or empty, skip this update
      if (newGram === 0 && newKg === 0 && newLitre === 0 && newPieces === 0 && newBoxes === 0) {
        continue;
      }
      
      // Note: It's perfectly fine to fill only one column (e.g., only litre or only kg)
      // The remaining stock will be calculated automatically based on what you enter

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
        [finalItemId]
      );

      const totalTakenGram = parseNumeric(dailyStockQuery.rows[0]?.total_gram || '0');
      const totalTakenKg = parseNumeric(dailyStockQuery.rows[0]?.total_kg || '0');
      const totalTakenLitre = parseNumeric(dailyStockQuery.rows[0]?.total_litre || '0');
      const totalTakenPieces = parseNumeric(dailyStockQuery.rows[0]?.total_pieces || '0');
      const totalTakenBoxes = parseNumeric(dailyStockQuery.rows[0]?.total_boxes || '0');

      // Convert everything to grams for unified calculation
      // 1 litre = 1000 gram (for ghee/liquids, assuming similar density to water)
      // 1 kg = 1000 gram
      const newStockInGram = newGram + (newKg * 1000) + (newLitre * 1000);
      const totalTakenInGram = totalTakenGram + (totalTakenKg * 1000) + (totalTakenLitre * 1000);
      
      // Calculate total remaining in grams (for gram/kg/litre)
      let totalRemainingInGram = Math.max(0, newStockInGram - totalTakenInGram);
      
      // Convert to different units for display
      // All three columns show the same remaining quantity in different units:
      // - Remaining Stock in gram: total remaining in grams (e.g., 4750)
      // - Remaining Stock in kg: total remaining converted to kg (e.g., 4.75)
      // - Remaining Stock in litre: total remaining converted to litres (e.g., 4.75)
      // Note: Using 1 litre = 1000 gram and 1 kg = 1000 gram for conversion
      const remainingKg = totalRemainingInGram / 1000; // Decimal value (e.g., 4.75)
      const remainingLitre = totalRemainingInGram / 1000; // Same as kg (e.g., 4.75)
      
      // Calculate remaining pieces separately (pieces don't convert to gram/kg/litre)
      const remainingPieces = Math.max(0, newPieces - totalTakenPieces);
      
      // Calculate remaining boxes separately (boxes don't convert to gram/kg/litre/pieces)
      const remainingBoxes = Math.max(0, newBoxes - totalTakenBoxes);
      
      // Example: 5 kg new stock - 250 gram taken = 4750 gram remaining
      // Display: 4750 gram, 4.75 kg, 4.75 litre

      // Use UPSERT to handle both insert and update
      // Since item_id has a UNIQUE constraint, we can use ON CONFLICT
      const result = await db.query(
        `INSERT INTO overall_stock (
          item_id, 
          remaining_stock_gram, remaining_stock_kg, remaining_stock_litre, remaining_stock_pieces, remaining_stock_boxes,
          new_stock_gram, new_stock_kg, new_stock_litre, new_stock_pieces, new_stock_boxes
        ) 
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11) 
         ON CONFLICT (item_id) 
         DO UPDATE SET 
           remaining_stock_gram = EXCLUDED.remaining_stock_gram,
           remaining_stock_kg = EXCLUDED.remaining_stock_kg,
           remaining_stock_litre = EXCLUDED.remaining_stock_litre,
           remaining_stock_pieces = EXCLUDED.remaining_stock_pieces,
           remaining_stock_boxes = EXCLUDED.remaining_stock_boxes,
           new_stock_gram = EXCLUDED.new_stock_gram,
           new_stock_kg = EXCLUDED.new_stock_kg,
           new_stock_litre = EXCLUDED.new_stock_litre,
           new_stock_pieces = EXCLUDED.new_stock_pieces,
           new_stock_boxes = EXCLUDED.new_stock_boxes,
           updated_at = CURRENT_TIMESTAMP
         RETURNING *`,
        [
          finalItemId,
          totalRemainingInGram, // Store full remaining amount in grams (e.g., 4750)
          remainingKg, // Store in kg with decimal (e.g., 4.75)
          remainingLitre, // Store in litre with decimal (e.g., 4.75)
          remainingPieces, // Store remaining pieces
          remainingBoxes, // Store remaining boxes
          newGram,
          newKg,
          newLitre,
          newPieces,
          newBoxes,
        ]
      );
      
      if (result.rows.length > 0) {
        results.push(result.rows[0]);
      }
    }

    res.json(results);
  } catch (err) {
    console.error('Error updating overall stock:', err);
    res.status(500).json({
      message: 'Error updating overall stock',
      error: process.env.NODE_ENV === 'development' ? err.message : undefined
    });
  }
});

export default router;

