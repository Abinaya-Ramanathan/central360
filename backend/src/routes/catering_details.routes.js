import { Router } from 'express';
import db from '../db.js';

const router = Router();

// Get catering details
router.get('/', async (req, res) => {
  try {
    const { booking_id } = req.query;
    let query = 'SELECT * FROM catering_details WHERE 1=1';
    const params = [];
    let paramCount = 1;

    if (booking_id) {
      query += ` AND booking_id = $${paramCount++}`;
      params.push(booking_id);
    }

    query += ' ORDER BY created_at DESC';
    const { rows } = await db.query(query, params);
    res.json(rows);
  } catch (err) {
    console.error('Error fetching catering details:', err);
    res.status(500).json({ message: 'Error fetching catering details' });
  }
});

// Create or update catering details
router.post('/', async (req, res) => {
  try {
    const {
      booking_id,
      delivery_location,
      morning_food_menu,
      morning_food_count,
      afternoon_food_menu,
      afternoon_food_count,
      evening_food_menu,
      evening_food_count,
    } = req.body;

    if (!booking_id) {
      return res.status(400).json({ message: 'Booking ID is required' });
    }

    // Check if booking_id exists in mahal_bookings
    const checkBooking = await db.query(
      'SELECT booking_id FROM mahal_bookings WHERE booking_id = $1',
      [booking_id]
    );

    if (checkBooking.rows.length === 0) {
      return res.status(404).json({ message: 'Booking ID not found in Event Details' });
    }

    const result = await db.query(
      `INSERT INTO catering_details (
        booking_id, delivery_location, morning_food_menu, morning_food_count,
        afternoon_food_menu, afternoon_food_count,
        evening_food_menu, evening_food_count
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
      ON CONFLICT (booking_id) DO UPDATE SET
        delivery_location = EXCLUDED.delivery_location,
        morning_food_menu = EXCLUDED.morning_food_menu,
        morning_food_count = EXCLUDED.morning_food_count,
        afternoon_food_menu = EXCLUDED.afternoon_food_menu,
        afternoon_food_count = EXCLUDED.afternoon_food_count,
        evening_food_menu = EXCLUDED.evening_food_menu,
        evening_food_count = EXCLUDED.evening_food_count,
        updated_at = CURRENT_TIMESTAMP
      RETURNING *`,
      [
        booking_id,
        delivery_location || null,
        morning_food_menu || null,
        morning_food_count || 0,
        afternoon_food_menu || null,
        afternoon_food_count || 0,
        evening_food_menu || null,
        evening_food_count || 0,
      ]
    );

    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error('Error saving catering details:', err);
    res.status(500).json({
      message: 'Error saving catering details',
      error: process.env.NODE_ENV === 'development' ? err.message : undefined
    });
  }
});

// Delete catering details
router.delete('/:booking_id', async (req, res) => {
  try {
    const { booking_id } = req.params;

    const result = await db.query(
      'DELETE FROM catering_details WHERE booking_id = $1 RETURNING *',
      [booking_id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ message: 'Catering details not found' });
    }

    res.status(200).json({ message: 'Catering details deleted successfully' });
  } catch (err) {
    console.error('Error deleting catering details:', err);
    res.status(500).json({
      message: 'Error deleting catering details',
      error: process.env.NODE_ENV === 'development' ? err.message : undefined
    });
  }
});

export default router;

