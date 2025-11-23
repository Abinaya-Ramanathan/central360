import { Router } from 'express';
import db from '../db.js';

const router = Router();

// Get expense details
router.get('/', async (req, res) => {
  try {
    const { booking_id } = req.query;
    let query = `SELECT 
      *,
      (
        COALESCE(master_salary, 0) +
        COALESCE(cooking_helper_salary, 0) +
        COALESCE(external_catering_salary, 0) +
        COALESCE(current_bill, 0) +
        COALESCE(cleaning_bill, 0) +
        COALESCE(grocery_bill, 0) +
        COALESCE(vegetable_bill, 0) +
        COALESCE(cylinder_amount, 0) +
        COALESCE(morning_food_expense, 0) +
        COALESCE(afternoon_food_expense, 0) +
        COALESCE(evening_food_expense, 0) +
        COALESCE(vehicle_expense, 0) +
        COALESCE(packing_items_charge, 0)
      ) AS total_expense
    FROM expense_details WHERE 1=1`;
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
    console.error('Error fetching expense details:', err);
    res.status(500).json({ message: 'Error fetching expense details' });
  }
});

// Create or update expense details
router.post('/', async (req, res) => {
  try {
    const {
      booking_id,
      master_salary,
      cooking_helper_salary,
      external_catering_salary,
      current_bill,
      cleaning_bill,
      grocery_bill,
      vegetable_bill,
      cylinder_amount,
      morning_food_expense,
      afternoon_food_expense,
      evening_food_expense,
      vehicle_expense,
      packing_items_charge,
      details,
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
      `INSERT INTO expense_details (
        booking_id, master_salary, cooking_helper_salary,
        external_catering_salary, current_bill, cleaning_bill,
        grocery_bill, vegetable_bill, cylinder_amount,
        morning_food_expense, afternoon_food_expense, evening_food_expense,
        vehicle_expense, packing_items_charge, details
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)
      ON CONFLICT (booking_id) DO UPDATE SET
        master_salary = EXCLUDED.master_salary,
        cooking_helper_salary = EXCLUDED.cooking_helper_salary,
        external_catering_salary = EXCLUDED.external_catering_salary,
        current_bill = EXCLUDED.current_bill,
        cleaning_bill = EXCLUDED.cleaning_bill,
        grocery_bill = EXCLUDED.grocery_bill,
        vegetable_bill = EXCLUDED.vegetable_bill,
        cylinder_amount = EXCLUDED.cylinder_amount,
        morning_food_expense = EXCLUDED.morning_food_expense,
        afternoon_food_expense = EXCLUDED.afternoon_food_expense,
        evening_food_expense = EXCLUDED.evening_food_expense,
        vehicle_expense = EXCLUDED.vehicle_expense,
        packing_items_charge = EXCLUDED.packing_items_charge,
        details = EXCLUDED.details,
        total_expense = (
          COALESCE(EXCLUDED.master_salary, 0) +
          COALESCE(EXCLUDED.cooking_helper_salary, 0) +
          COALESCE(EXCLUDED.external_catering_salary, 0) +
          COALESCE(EXCLUDED.current_bill, 0) +
          COALESCE(EXCLUDED.cleaning_bill, 0) +
          COALESCE(EXCLUDED.grocery_bill, 0) +
          COALESCE(EXCLUDED.vegetable_bill, 0) +
          COALESCE(EXCLUDED.cylinder_amount, 0) +
          COALESCE(EXCLUDED.morning_food_expense, 0) +
          COALESCE(EXCLUDED.afternoon_food_expense, 0) +
          COALESCE(EXCLUDED.evening_food_expense, 0) +
          COALESCE(EXCLUDED.vehicle_expense, 0) +
          COALESCE(EXCLUDED.packing_items_charge, 0)
        ),
        updated_at = CURRENT_TIMESTAMP
      RETURNING *`,
      [
        booking_id,
        master_salary || 0,
        cooking_helper_salary || 0,
        external_catering_salary || 0,
        current_bill || 0,
        cleaning_bill || 0,
        grocery_bill || 0,
        vegetable_bill || 0,
        cylinder_amount || 0,
        morning_food_expense || 0,
        afternoon_food_expense || 0,
        evening_food_expense || 0,
        vehicle_expense || 0,
        packing_items_charge || 0,
        details || null,
      ]
    );

    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error('Error saving expense details:', err);
    res.status(500).json({
      message: 'Error saving expense details',
      error: process.env.NODE_ENV === 'development' ? err.message : undefined
    });
  }
});

// Delete expense details
router.delete('/:booking_id', async (req, res) => {
  try {
    const { booking_id } = req.params;

    const result = await db.query(
      'DELETE FROM expense_details WHERE booking_id = $1 RETURNING *',
      [booking_id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ message: 'Expense details not found' });
    }

    res.status(200).json({ message: 'Expense details deleted successfully' });
  } catch (err) {
    console.error('Error deleting expense details:', err);
    res.status(500).json({
      message: 'Error deleting expense details',
      error: process.env.NODE_ENV === 'development' ? err.message : undefined
    });
  }
});

export default router;

