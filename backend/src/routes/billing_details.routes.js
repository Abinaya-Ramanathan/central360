import { Router } from 'express';
import db from '../db.js';

const router = Router();

// Get billing details
router.get('/', async (req, res) => {
  try {
    const { booking_id } = req.query;
    let query = 'SELECT * FROM billing_details WHERE 1=1';
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
    console.error('Error fetching billing details:', err);
    res.status(500).json({ message: 'Error fetching billing details' });
  }
});

// Create or update billing details
router.post('/', async (req, res) => {
  try {
    const {
      booking_id,
      current_charge,
      cleaning_charge,
      vessel_charge,
      function_hall_charge,
      dining_hall_charge,
      grocery_charge,
      vegetable_charge,
      morning_food,
      afternoon_food,
      night_food,
      cylinder_quantity,
      cylinder_amount,
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
      `INSERT INTO billing_details (
        booking_id, current_charge, cleaning_charge, vessel_charge,
        function_hall_charge, dining_hall_charge, grocery_charge,
        vegetable_charge, morning_food, afternoon_food, night_food,
        cylinder_quantity, cylinder_amount
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
      ON CONFLICT (booking_id) DO UPDATE SET
        current_charge = EXCLUDED.current_charge,
        cleaning_charge = EXCLUDED.cleaning_charge,
        vessel_charge = EXCLUDED.vessel_charge,
        function_hall_charge = EXCLUDED.function_hall_charge,
        dining_hall_charge = EXCLUDED.dining_hall_charge,
        grocery_charge = EXCLUDED.grocery_charge,
        vegetable_charge = EXCLUDED.vegetable_charge,
        morning_food = EXCLUDED.morning_food,
        afternoon_food = EXCLUDED.afternoon_food,
        night_food = EXCLUDED.night_food,
        cylinder_quantity = EXCLUDED.cylinder_quantity,
        cylinder_amount = EXCLUDED.cylinder_amount,
        updated_at = CURRENT_TIMESTAMP
      RETURNING *`,
      [
        booking_id,
        current_charge || 0,
        cleaning_charge || 0,
        vessel_charge || 0,
        function_hall_charge || 0,
        dining_hall_charge || 0,
        grocery_charge || 0,
        vegetable_charge || 0,
        morning_food || 0,
        afternoon_food || 0,
        night_food || 0,
        cylinder_quantity || 0,
        cylinder_amount || 0,
      ]
    );

    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error('Error saving billing details:', err);
    res.status(500).json({
      message: 'Error saving billing details',
      error: process.env.NODE_ENV === 'development' ? err.message : undefined
    });
  }
});

// Delete billing details
router.delete('/:booking_id', async (req, res) => {
  try {
    const { booking_id } = req.params;

    const result = await db.query(
      'DELETE FROM billing_details WHERE booking_id = $1 RETURNING *',
      [booking_id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ message: 'Billing details not found' });
    }

    res.status(200).json({ message: 'Billing details deleted successfully' });
  } catch (err) {
    console.error('Error deleting billing details:', err);
    res.status(500).json({
      message: 'Error deleting billing details',
      error: process.env.NODE_ENV === 'development' ? err.message : undefined
    });
  }
});

export default router;

