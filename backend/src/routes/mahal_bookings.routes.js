import { Router } from 'express';
import db from '../db.js';

const router = Router();

// Get mahal bookings
router.get('/', async (req, res) => {
  try {
    const { sector } = req.query;
    let query = 'SELECT * FROM mahal_bookings WHERE 1=1';
    const params = [];
    let paramCount = 1;

    if (sector) {
      query += ` AND sector_code = $${paramCount++}`;
      params.push(sector);
    }

    query += ' ORDER BY event_date DESC, created_at DESC';
    const { rows } = await db.query(query, params);
    res.json(rows);
  } catch (err) {
    console.error('Error fetching mahal bookings:', err);
    res.status(500).json({ message: 'Error fetching mahal bookings' });
  }
});

// Create or update mahal booking
router.post('/', async (req, res) => {
  try {
    const {
      booking_id,
      sector_code,
      mahal_detail,
      event_date,
      event_timing,
      event_name,
      client_name,
      client_phone1,
      client_phone2,
      client_address,
      food_service,
      advance_received,
      quoted_amount,
      amount_received,
      final_settlement_amount,
      order_status,
      details,
    } = req.body;

    if (!sector_code || !mahal_detail || !event_date || !client_name) {
      return res.status(400).json({ 
        message: 'Sector code, mahal detail, event date, and client name are required' 
      });
    }

    // Generate booking_id if not provided: client_name + event_date
    let generatedBookingId = booking_id;
    if (!generatedBookingId) {
      // Remove spaces and special characters from client_name for booking_id
      const cleanClientName = client_name.replace(/[^a-zA-Z0-9]/g, '');
      generatedBookingId = `${cleanClientName}_${event_date}`;
    }

    // Always use INSERT ... ON CONFLICT to handle both create and update
    // This ensures new records are created even if booking_id is provided
    const result = await db.query(
      `INSERT INTO mahal_bookings (
        booking_id, sector_code, mahal_detail, event_date, event_timing,
        event_name, client_name, client_phone1, client_phone2, client_address, 
        food_service, advance_received, quoted_amount, amount_received, final_settlement_amount, order_status, details
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17)
      ON CONFLICT (booking_id) DO UPDATE SET
        sector_code = EXCLUDED.sector_code,
        mahal_detail = EXCLUDED.mahal_detail,
        event_date = EXCLUDED.event_date,
        event_timing = EXCLUDED.event_timing,
        event_name = EXCLUDED.event_name,
        client_name = EXCLUDED.client_name,
        client_phone1 = EXCLUDED.client_phone1,
        client_phone2 = EXCLUDED.client_phone2,
        client_address = EXCLUDED.client_address,
        food_service = EXCLUDED.food_service,
        advance_received = EXCLUDED.advance_received,
        quoted_amount = EXCLUDED.quoted_amount,
        amount_received = EXCLUDED.amount_received,
        final_settlement_amount = EXCLUDED.final_settlement_amount,
        order_status = EXCLUDED.order_status,
        details = EXCLUDED.details,
        updated_at = CURRENT_TIMESTAMP
      RETURNING *`,
      [
        generatedBookingId,
        sector_code,
        mahal_detail,
        event_date,
        event_timing || null,
        event_name || null,
        client_name,
        client_phone1 || null,
        client_phone2 || null,
        client_address || null,
        food_service || null,
        advance_received || null,
        quoted_amount || null,
        amount_received || null,
        final_settlement_amount || null,
        order_status || 'open',
        details || null,
      ]
    );
    const rows = result.rows;

    res.status(201).json(rows[0]);
  } catch (err) {
    console.error('Error saving mahal booking:', err);
    res.status(500).json({
      message: 'Error saving event details',
      error: process.env.NODE_ENV === 'development' ? err.message : undefined
    });
  }
});

// Delete mahal booking
router.delete('/:booking_id', async (req, res) => {
  try {
    const { booking_id } = req.params;

    const result = await db.query(
      'DELETE FROM mahal_bookings WHERE booking_id = $1 RETURNING *',
      [booking_id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ message: 'Event details not found' });
    }

    res.status(200).json({ message: 'Event details deleted successfully' });
  } catch (err) {
    console.error('Error deleting event details:', err);
    res.status(500).json({
      message: 'Error deleting event details',
      error: process.env.NODE_ENV === 'development' ? err.message : undefined
    });
  }
});

export default router;

